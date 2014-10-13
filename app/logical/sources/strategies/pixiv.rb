﻿# encoding: UTF-8

require 'csv'

module Sources
  class Error < StandardError ; end

  module Strategies
    class Pixiv < Base
      MONIKER   = '(?:[a-zA-Z0-9_-]+)'
      TIMESTAMP = '(?:[0-9]{4}/[0-9]{2}/[0-9]{2}/[0-9]{2}/[0-9]{2}/[0-9]{2})'
      EXT = "(?:jpg|jpeg|png|gif)"

      WEB = "^(?:https?://)?www\\.pixiv\\.net"
      I12 = "^(?:https?://)?i[12]\\.pixiv\\.net"
      IMG = "^(?:https?://)?img[0-9]*\\.pixiv\\.net"

      def self.url_match?(url)
        url =~ /#{WEB}|#{IMG}|#{I12}/i
      end

      def referer_url(template)
        if template.params[:ref] =~ /pixiv\.net\/member_illust/ && template.params[:ref] =~ /mode=medium/
          template.params[:ref]
        else
          template.params[:url]
        end
      end

      def site_name
        "Pixiv"
      end

      def unique_id
        @pixiv_moniker
      end

      def normalizable_for_artist_finder?
        has_moniker? || sample_image? || full_image? || work_page?
      end

      def normalize_for_artist_finder!
        if has_moniker?
          moniker = get_moniker_from_url
        else
          illust_id = illust_id_from_url(url)
          get_metadata_from_spapi!(illust_id) do |metadata|
            moniker = metadata[24]
          end
        end

        "http://img.pixiv.net/img/#{moniker}/"
      end

      def get
        agent.get(URI.parse(normalized_url)) do |page|
          @artist_name, @profile_url = get_profile_from_page(page)
          @pixiv_moniker = get_moniker_from_page(page)
          @tags = get_tags_from_page(page)
          @page_count = get_page_count_from_page(page)

          is_manga   = @page_count > 1
          @image_url = get_image_url_from_page(page, is_manga)
        end
      end

      def rewrite_thumbnails(thumbnail_url, is_manga=nil)
        thumbnail_url = rewrite_new_medium_images(thumbnail_url)
        thumbnail_url = rewrite_old_small_and_medium_images(thumbnail_url, is_manga)
        return thumbnail_url
      end

    protected

      # http://i1.pixiv.net/c/600x600/img-master/img/2014/10/02/13/51/23/46304396_p1_master1200.jpg
      # => http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p1.png
      def rewrite_new_medium_images(thumbnail_url)
        if thumbnail_url =~ %r!/c/\d+x\d+/img-master/img/#{TIMESTAMP}/\d+_p\d+_\w+\.jpg!i
          thumbnail_url = thumbnail_url.sub(%r!/c/\d+x\d+/img-master/!i, '/img-original/')
          # => http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p1_master1200.jpg

          page = manga_page_from_url(@url)
          thumbnail_url = thumbnail_url.sub(%r!_p(\d+)_\w+\.jpg$!i, "_p#{page}.")
          # => http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p1.

          illust_id = illust_id_from_url(@url)
          get_metadata_from_spapi!(illust_id) do |metadata|
            file_ext = metadata[2]
            thumbnail_url += file_ext
            # => http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p1.png
          end
        end

        thumbnail_url
      end

      # If the thumbnail is for a manga gallery, it needs to be rewritten like this:
      #
      # http://i2.pixiv.net/img18/img/evazion/14901720_m.png
      # => http://i2.pixiv.net/img18/img/evazion/14901720_big_p0.png
      #
      # Otherwise, it needs to be rewritten like this:
      #
      # http://i2.pixiv.net/img18/img/evazion/14901720_m.png
      # => http://i2.pixiv.net/img18/img/evazion/14901720.png
      #
      def rewrite_old_small_and_medium_images(thumbnail_url, is_manga)
        if thumbnail_url =~ %r!/img/#{MONIKER}/\d+_[ms]\.#{EXT}!i
          if is_manga.nil?
            illust_id = illust_id_from_url(@url)
            get_metadata_from_spapi!(illust_id) do |metadata|
              page_count = metadata[19].to_i || 1
              is_manga   = page_count > 1
            end
          end

          if is_manga
            page = manga_page_from_url(@url)
            return thumbnail_url.sub(/_[ms]\./, "_big_p#{page}.")
          else
            return thumbnail_url.sub(/_[ms]\./, ".")
          end
        end

        return thumbnail_url
      end

      def manga_page_from_url(url)
        # http://i2.pixiv.net/img04/img/syounen_no_uta/46170939_p0.jpg
        # http://i1.pixiv.net/c/600x600/img-master/img/2014/09/24/23/25/08/46168376_p0_master1200.jpg
        # http://i1.pixiv.net/img-original/img/2014/09/25/23/09/29/46183440_p0.jpg
        if url =~ %r!/\d+_p(\d+)(?:_\w+)?\.#{EXT}!i
          $1

        # http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=46170939&page=0
        elsif url =~ /page=(\d+)/i
          $1

        else
          0
        end
      end

      def get_profile_from_page(page)
        profile_url = page.search("a.user-link").first
        if profile_url
          profile_url = "http://www.pixiv.net" + profile_url["href"]
        end

        artist_name = page.search("h1.user").first
        if artist_name
          artist_name = artist_name.inner_text
        end

        return [artist_name, profile_url]
      end

      def get_moniker_from_page(page)
        # <a class="tab-feed" href="/stacc/gennmai-226">Feed</a>
        stacc_link = page.search("a.tab-feed").first

        if not stacc_link.nil?
          stacc_link.attr("href").sub(%r!^/stacc/!i, '')
        else
          raise Sources::Error.new("Couldn't find Pixiv moniker in page: #{normalized_url}")
        end
      end

      def get_moniker_from_url
        case url
        when %r!#{IMG}/img/(#{MONIKER})!i
          $1
        when %r!#{I12}/img[0-9]+/img/(#{MONIKER})!i
          $1
        when %r!#{WEB}/stacc/(#{MONIKER})/?$!i
          $1
        else
          false
        end
      end

      def has_moniker?
        get_moniker_from_url != false
      end

      def get_image_url_from_page(page, is_manga)
        elements = page.search("div.works_display a img").find_all do |node|
          node["src"] !~ /source\.pixiv\.net/
        end

        if elements.any?
          thumbnail_url = elements.first.attr("src")
          return rewrite_thumbnails(thumbnail_url, is_manga)
        else
          raise Sources::Error.new("Couldn't find image thumbnail URL in page: #{normalized_url}")
        end
      end

      def get_tags_from_page(page)
        # puts page.root.to_xhtml

        links = page.search("ul.tags a.text").find_all do |node|
          node["href"] =~ /search\.php/
        end

        original_flag = page.search("a.original-works")

        if links.any?
          links.map! do |node|
            [node.inner_text, "http://www.pixiv.net" + node.attr("href")]
          end

          if original_flag.any?
            links << ["オリジナル", "http://www.pixiv.net/search.php?s_mode=s_tag_full&word=%E3%82%AA%E3%83%AA%E3%82%B8%E3%83%8A%E3%83%AB"]
          end

          links
        else
          []
        end
      end

      def get_page_count_from_page(page)
        elements = page.search("ul.meta li").find_all do |node|
          node.text =~ /Manga|漫画|複数枚投稿/
        end

        if elements.any?
          elements[0].text =~ /(?:Manga|漫画|複数枚投稿) (\d+)P/
          $1.to_i
        else
          1
        end
      end

      def normalized_url
        illust_id = illust_id_from_url(@url)
        "http://www.pixiv.net/member_illust.php?mode=medium&illust_id=#{illust_id}"
      end

      # Refer to http://danbooru.donmai.us/wiki_pages/58938 for documentation on the Pixiv API.
      def get_metadata_from_spapi!(illust_id)
        phpsessid = agent.cookies.select do |cookie| cookie.name == "PHPSESSID" end.first.value
        spapi_url = "http://spapi.pixiv.net/iphone/illust.php?illust_id=#{illust_id}&PHPSESSID=#{phpsessid}"

        agent.get(spapi_url) do |response|
          metadata = CSV.parse(response.content.force_encoding("UTF-8")).first

          validate_spapi_metadata!(metadata)
          yield metadata
        end
      end

      def validate_spapi_metadata!(metadata)
        if metadata.nil?
          raise Sources::Error.new("Pixiv API returned empty response.")
        elsif metadata.size != 31
          raise Sources::Error.new("Pixiv API returned unexpected number of fields.")
        end

        illust_id  = metadata[0]
        file_ext   = metadata[2]
        page_count = metadata[19]
        moniker    = metadata[24]
        mobile_profile_image = metadata[30]

        if file_ext !~ /#{EXT}/i
          raise Sources::Error.new("Pixiv API returned unexpected file extension '#{file_ext}' for pixiv ##{illust_id}.")
        elsif moniker !~ /#{MONIKER}/i
          raise Sources::Error.new("Pixiv API returned invalid artist moniker '#{moniker}' for pixiv ##{illust_id}.")
        elsif page_count.to_s !~ /[0-9]*/i
          raise Sources::Error.new("Pixiv API returned invalid page count '#{page_count}' for pixiv ##{illust_id}.")
        end

        if mobile_profile_image
          # http://i1.pixiv.net/img01/profile/ccz67420/mobile/5042957_80.jpg
          profile_regex  = %r!i[12]\.pixiv\.net/img\d+/profile/#{MONIKER}/mobile/\d+_\d+\.jpg!i
          mobile_moniker = mobile_profile_image.match(profile_regex)[1]

          if mobile_moniker != moniker
            raise Sources::Error.new("Pixiv API returned inconsistent artist moniker '#{moniker}' for pixiv ##{illust_id}.")
          end
        end
      end

      def illust_id_from_url(url)
        # http://img18.pixiv.net/img/evazion/14901720.png
        #
        # http://i2.pixiv.net/img18/img/evazion/14901720.png
        # http://i2.pixiv.net/img18/img/evazion/14901720_m.png
        # http://i2.pixiv.net/img18/img/evazion/14901720_s.png
        # http://i1.pixiv.net/img07/img/pasirism/18557054_p1.png
        # http://i1.pixiv.net/img07/img/pasirism/18557054_big_p1.png
        #
        # http://i1.pixiv.net/img-inf/img/2011/05/01/23/28/04/18557054_64x64.jpg
        # http://i1.pixiv.net/img-inf/img/2011/05/01/23/28/04/18557054_s.png
        #
        # http://i1.pixiv.net/c/600x600/img-master/img/2014/10/02/13/51/23/46304396_p0_master1200.jpg
        # http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p0.png
        #
        # http://i1.pixiv.net/img-zip-ugoira/img/2014/10/03/17/29/16/46323924_ugoira1920x1080.zip
        if url =~ %r!/(\d+)(?:_\w+)?\.(?:jpg|jpeg|png|gif|zip)!i
          $1

        # http://www.pixiv.net/member_illust.php?mode=medium&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=big&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=manga&illust_id=18557054
        # http://www.pixiv.net/member_illust.php?mode=manga_big&illust_id=18557054&page=1
        elsif url =~ /illust_id=(\d+)/i
          $1

        # http://www.pixiv.net/i/18557054
        elsif url =~ %r!pixiv\.net/i/(\d+)!i
          $1

        else
          raise Sources::Error.new("Couldn't get illust ID from URL: #{url}")
        end
      end

      def work_page?
        return true if url =~ %r!#{WEB}/member_illust\.php\?mode=(?:medium|big|manga|manga_big)&illust_id=\d+!i
        return true if url =~ %r!#{WEB}/i/\d+$!i
        return false
      end

      def full_image?
        # http://img18.pixiv.net/img/evazion/14901720.png?1234
        return true if url =~ %r!#{IMG}/img/#{MONIKER}/\d+(?:_big_p\d+)?\.#{EXT}!i

        # http://i2.pixiv.net/img18/img/evazion/14901720.png
        # http://i1.pixiv.net/img07/img/pasirism/18557054_big_p1.png
        return true if url =~ %r!#{I12}/img\d+/img/#{MONIKER}/\d+(?:_big_p\d+)?\.#{EXT}!i

        # http://i1.pixiv.net/img-original/img/2014/10/02/13/51/23/46304396_p0.png
        return true if url =~ %r!#{I12}/img-original/img/#{TIMESTAMP}/\d+_p\d+\.#{EXT}$!i

        # http://i1.pixiv.net/img-zip-ugoira/img/2014/10/03/17/29/16/46323924_ugoira1920x1080.zip
        return true if url =~ %r!#{I12}/img-zip-ugoira/img/#{TIMESTAMP}/\d+_ugoira\d+x\d+\.zip$!i

        return false
      end

      def sample_image?
        # http://img18.pixiv.net/img/evazion/14901720_m.png
        return true if url =~ %r!#{IMG}/img/#{MONIKER}/\d+_(?:[sm]|p\d+)\.#{EXT}!i

        # http://i2.pixiv.net/img18/img/evazion/14901720_m.png
        # http://i1.pixiv.net/img07/img/pasirism/18557054_p1.png
        return true if url =~ %r!#{I12}/img\d+/img/#{MONIKER}/\d+_(?:[sm]|p\d+)\.#{EXT}!i

        # http://i1.pixiv.net/c/600x600/img-master/img/2014/10/02/13/51/23/46304396_p0_master1200.jpg
        # http://i2.pixiv.net/c/64x64/img-master/img/2014/10/09/12/59/50/46441917_square1200.jpg
        return true if url =~ %r!#{I12}/c/\d+x\d+/img-master/img/#{TIMESTAMP}/\d+_\w+\.#{EXT}$!i

        # http://i1.pixiv.net/img-inf/img/2011/05/01/23/28/04/18557054_s.png
        # http://i2.pixiv.net/img-inf/img/2010/11/30/08/54/06/14901765_64x64.jpg
        return true if url =~ %r!#{I12}/img-inf/img/#{TIMESTAMP}/\d+_\w+\.#{EXT}!i

        return false
      end

      def agent
        @agent ||= begin
          mech = Mechanize.new

          phpsessid = Cache.get("pixiv-phpsessid")
          if phpsessid
            cookie = Mechanize::Cookie.new("PHPSESSID", phpsessid)
            cookie.domain = ".pixiv.net"
            cookie.path = "/"
            mech.cookie_jar.add(cookie)
          else
            mech.get("http://www.pixiv.net") do |page|
              page.form_with(:action => "/login.php") do |form|
                form['pixiv_id'] = Danbooru.config.pixiv_login
                form['pass'] = Danbooru.config.pixiv_password
              end.click_button
            end
            phpsessid = mech.cookie_jar.cookies.select{|c| c.name == "PHPSESSID"}.first
            Cache.put("pixiv-phpsessid", phpsessid.value, 1.month) if phpsessid
          end

          mech
        end
      end
    end
  end
end
