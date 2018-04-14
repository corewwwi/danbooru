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

      posts_with_tags = Post.from(sample).with_unflattened_tags
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

  # Finds tags related to a given tag according to Jaccard similarity. The
  # Jaccard similarity of two sets is the size of their intersection divided by
  # the size of their union:
  #
  #   J(A, B) = |A ∩ B| / |A ∪ B|
  #           = |A ∩ B| / (|A| + |B| - |A ∩ B|)
  #
  # For tags, the size of the intersection is the post count of an AND search,
  # while the size of the union is the post count of an OR search:
  #
  #   |A ∩ B| = {{tagA tagB}}
  #   |A ∪ B| = {{~tagA ~tagB}} = {{tagA}} + {{tagB}} - {{tagA tagB}}
  #
  #   J(tagA, tagB) = {{tagA tagB}} / ({{tagA}} + {{tagB}} - {{tagA tagB}})
  #
  # The naive way to find related tags would be to do {{tagA tagB}} searches for each
  # possible pair of related tags. This would be slow, so we optimize it in two ways:
  #
  # * For small tags, we collect the full set of posts and count how many times each tag
  # occurs. This gives us all the tag intersection counts in a single tag search.
  #
  # * For large tags, we approximate the similarity using MinHash. MinHash uses
  # a random sample of posts from each tag, and these samples are cached. We
  # effectively only do one search per tag, even to evaluate many pairs of tags.
  #
  # https://en.wikipedia.org/wiki/MinHash
  # https://robertheaton.com/2014/05/02/jaccard-similarity-and-minhash-for-winners/
  concerning :JaccardMethods do
    # The number of posts to sample from each tag. The expected error of the MinHash
    # approximation is 1 / sqrt(SAMPLE_SIZE), so a size of 625 posts gives a 4% error.
    SAMPLE_SIZE = 625

    class_methods do
      # Calculate the top N tags most similar to the given tag search.
      # @return [Hash{String => Float] a hash of tag names to similarity values
      def similar_tags(search, n: 50, sample_size: SAMPLE_SIZE)
        search_count = CurrentUser.without_safe_mode { Post.fast_count(search) }

        if search_count <= sample_size
          tags_with_similarities = similar_tags_by_jaccard(search)
        else
          tags_with_similarities = similar_tags_by_minhash(search, n: n, sample_size: sample_size)
        end

        tags_with_similarities.sort_by { |tag, similarity| [-similarity, tag] }.take(n).to_h
      end

      # Calculate the tags most similar to the given tag search by the Jaccard index.
      # @return [Hash{String => Float] a hash of tag names to similarity values
      def similar_tags_by_jaccard(search)
        posts = CurrentUser.without_safe_mode { Post.tag_match(search) }
        tags_with_counts = frequent_tags_for_posts(posts)

        tags_with_counts.map do |tag, intersection|
          union = posts.size + tag.post_count - intersection
          jaccard = intersection.to_f / union.to_f

          [tag.name, jaccard]
        end.to_h
      end

      # Calculate the top N tags most similar to the given tag search by MinHash similarity.
      # @return [Hash{String => Float] a hash of tag names to similarity values
      def similar_tags_by_minhash(search, n: 50, sample_size: SAMPLE_SIZE)
        candidate_tag_names = frequent_tags_for_search(search, n, sample_size)
        minhash_similarities(search, candidate_tag_names, sample_size: sample_size)
      end

      # Calculates the Jaccard similarity between a given tag and a list of
      # other tags. These can be arbitrary tag searches, not just single tags.
      #
      # The MinHash approximation is given by:
      #
      #   X = H(k, A ∪ B) = H(k, H(k, A) ∪ H(k, B))
      #   Y = X ∩ H(k, A) ∩ H(k, B)
      #   J(A, B) = |Y|/k
      #
      # where H(k, A) means apply a hash function H to each item in set A and take the
      # k smallest items. In other words: H(k, A) is a random sample of k items from set A.
      #
      # @return [Hash{String => Float] a hash of searches to similarity values
      def minhash_similarities(tag_search, candidate_searches, sample_size: SAMPLE_SIZE)
        sample_sets = sample_posts_for_searches([tag_search] + candidate_searches, sample_size)

        candidate_searches.map do |candidate_search|
          set_a = sample_sets[tag_search]
          set_b = sample_sets[candidate_search]

          x = (set_a + set_b).uniq.sort.take(sample_size)
          y = x & set_a & set_b
          jaccard = y.size.to_f / sample_size.to_f

          [candidate_search, jaccard]
        end.to_h
      end

      # Returns a cached random sample of posts for each tag search.
      # @return [Hash{String => [String]}] a hash of searches to lists of post md5s
      def sample_posts_for_searches(tag_searches, sample_size)
        samples = Cache.get_multi(tag_searches, "minhash:#{sample_size}", expires_in: 24.hours) do |tag_search|
          Post.sample(tag_search, sample_size).pluck(:md5)
        end
      end

      # Calculate the most frequently used tags on the given set of posts.
      # @return [Hash{Tag => Integer}] a hash from tags to tag frequency counts
      def frequent_tags_for_posts(posts)
        tag_names = posts.flat_map(&:tag_array)
        tags = Tag.where(name: tag_names.uniq).index_by(&:name)
        tags_with_counts = tag_names.group_by(&:itself).transform_keys(&tags).transform_values(&:count)

        tags_with_counts
      end

      # Calculate the N most frequently used tags in a sample of posts from the given search.
      # @return [Array<String>] a list of tag names
      def frequent_tags_for_search(search, n, sample_size)
        md5s = sample_posts_for_searches([search], sample_size)[search]
        Post.where(md5: md5s).with_unflattened_tags.order("count(*) DESC").limit(n).group(:tag).pluck(:tag)
      end
    end
  end
end
