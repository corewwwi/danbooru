class RelatedTagCalculator
  MAX_RESULTS = 25

  def self.calculate_from_sample_to_array(tags, category_constraint = nil)
    convert_hash_to_array(calculate_from_sample(tags, Danbooru.config.post_sample_size, category_constraint))
  end

  def self.calculate_from_posts_to_array(posts)
    convert_hash_to_array(calculate_from_posts(posts))
  end

  def self.calculate_from_posts(posts)
    counts = Hash.new {|h, k| h[k] = 0}

    posts.flat_map(&:tag_array).each do |tag|
      counts[tag] += 1
    end

    counts
  end

  def self.calculate_similar_from_sample(tag)
    # this uses cosine similarity to produce more useful
    # related tags, but is more db intensive
    counts = Hash.new {|h, k| h[k] = 0}

    CurrentUser.without_safe_mode do
      Post.with_timeout(5_000, [], {:tags => tag}) do
        Post.tag_match(tag).limit(400).reorder("posts.md5").pluck(:tag_string).each do |tag_string|
          tag_string.scan(/\S+/).each do |tag|
            counts[tag] += 1
          end
        end
      end
    end

    tag_record = Tag.find_by_name(tag)
    candidates = convert_hash_to_array(counts, 100)
    similar_counts = Hash.new {|h, k| h[k] = 0}
    CurrentUser.without_safe_mode do
      PostReadOnly.with_timeout(5_000, nil, {:tags => tag}) do
        candidates.each do |ctag, _|
          acount = PostReadOnly.tag_match("#{tag} #{ctag}").count
          ctag_record = Tag.find_by_name(ctag)
          div = Math.sqrt(tag_record.post_count * ctag_record.post_count)
          if div != 0
            c = acount / div
            similar_counts[ctag] = c
          end
        end
      end
    end

    convert_hash_to_array(similar_counts)
  end

  def self.calculate_from_sample(tags, sample_size, category_constraint = nil, max_results = MAX_RESULTS)
    Post.with_timeout(5_000, [], {:tags => tags}) do
      sample = Post.sample(tags, sample_size)
      posts_with_tags = Post.from(sample).with_unflattened_tags

      if category_constraint
        posts_with_tags = posts_with_tags.joins("JOIN tags ON tags.name = tag").where("tags.category" => category_constraint)
      end

      counts = posts_with_tags.order("count(*) DESC").limit(max_results).group("tag").count
      counts
    end
  end

  def self.convert_hash_to_array(hash, limit = MAX_RESULTS)
    hash.to_a.sort_by {|x| [-x[1], x[0]] }.slice(0, limit)
  end

  def self.convert_hash_to_string(hash)
    convert_hash_to_array(hash).flatten.join(" ")
  end

  # Calculate related tags using the MinHash approximation of the Jaccard index.
  #
  # The Jaccard similarity of two sets is the size of their intersection
  # divided by the size of their union:
  #
  #   J(A, B) = |A ∩ B| / |A ∪ B|
  #           = |A ∩ B| / (|A| + |B| - |A ∩ B|)
  #
  # For tags, the size of the intersection is the post count of an AND search,
  # while the size of the union is the post count of an OR search:
  #
  #   |A ∩ B| = {{tagA tagB}}
  #   |A ∪ B| = {{~tagA ~tagB}}
  #           = {{tagA}} + {{tagB}} - {{tagA tagB}}
  #
  #   J(tagA, tagB) = {{tagA tagB}} / ({{tagA}} + {{tagB}} - {{tagA tagB}})
  #
  # However, performing an intersection search ({{tagA tagB}}) is slow, especially
  # given that we have to do it for *every* potential pair of related tags.
  #
  # MinHash optimizes this by approximating the similarity using a random sample
  # of posts from both tags. We take the sample by essentially doing a
  # {{tag order:md5 limit:625}} search. These samples are cached, so effectively
  # we do one search per tag, no matter how many pairs of related tags we compare.
  #
  # https://en.wikipedia.org/wiki/MinHash
  # https://robertheaton.com/2014/05/02/jaccard-similarity-and-minhash-for-winners/
  concerning :JaccardMethods do
    # The number of posts to sample from each tag. The expected error of the MinHash
    # approximation is 1 / sqrt(SAMPLE_SIZE), so a size of 625 posts gives a 4% error.
    SAMPLE_SIZE = 625

    class_methods do
      # Calculate the top N tags most similar to the given tag search.
      #
      # @return [Hash{String => Float] a hash of tag names to similarity values
      def similar_tags(tag_search, n: 100, sample_size: SAMPLE_SIZE)
        candidate_tag_names = frequent_tags(tag_search, n, sample_size)
        tags_with_similarities = jaccard_similarities(tag_search, candidate_tag_names, sample_size)
        tags_with_similarities.sort_by { |tag, similarity| [-similarity, tag] }.to_h
      end

      # Calculate the N most frequently used tags on posts within the given search.
      #
      # @return [Array<String>] a list of N tag names
      def frequent_tags(tag_search, n, sample_size)
        md5s = samples_posts_for_searches([tag_search], sample_size)[tag_search]
        sample_posts = Post.where(md5: md5s)

        posts_with_tags = Post.from(sample_posts).with_unflattened_tags
        tag_names = posts_with_tags.order("count(*) DESC").group("tag").limit(n).pluck("tag")

        tag_names
      end

      # Calculates the approximate Jaccard similarity between a given tag and a
      # list of other tags. These can be any arbitrary tag searches, not just single tags.
      #
      # @return [Hash{String => Float] a hash of searches to similarity values
      def jaccard_similarities(tag_search, candidate_searches, sample_size)
        sample_posts = sample_posts_for_searches([tag_search] + candidate_searches, sample_size)

        candidate_searches.map do |candidate_search|
          sample_a = sample_posts[tag_search]
          sample_b = sample_posts[candidate_search]
          jaccard = fast_jaccard_similarity(sample_a, sample_b, sample_size)

          [candidate_search, jaccard]
        end.to_h
      end

      # Returns a cached random sample of posts for each tag search.
      #
      # @return [Hash{String => [String]}] a hash of searches to lists of post md5s
      def sample_posts_for_searches(tag_searches, sample_size)
        samples = Cache.get_multi(tag_searches, "minhash:#{sample_size}", expires_in: 24.hours) do |tag_search|
          Post.sample(tag_search, sample_size).pluck(:md5)
        end
      end

      # Approximate the Jaccard similarity between two sample sets using MinHash:
      #
      #   X = H(k, A ∪ B) = H(k, H(k, A) ∪ H(k, B))
      #   Y = X ∩ H(k, A) ∩ H(k, B)
      #   J(A, B) = |Y|/k
      #
      # where H(k, A) means apply a hash function H to each item in set A and take the
      # k smallest items. In other words: H(k, A) is a random sample of k items from set A.
      def fast_jaccard_similarity(a, b, sample_size)
        x = (a + b).uniq.sort.take(sample_size)
        y = x & a & b

        y.size.to_f / sample_size.to_f
      end

      # Calculate the exact Jaccard similarity between two tags (slow; reference only).
      def jaccard_similarity(tag1, tag2)
        CurrentUser.without_safe_mode do
          intersection = Post.tag_match("#{tag1} #{tag2}").count
          union = Tag.find_by_name(tag1).post_count + Tag.find_by_name(tag2).post_count - intersection

          intersection.to_f / union.to_f
        end
      end
    end
  end
end
