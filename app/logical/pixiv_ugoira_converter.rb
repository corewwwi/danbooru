class PixivUgoiraConverter
  attr_reader :write_path, :format

  def initialize(ugoira_file, frame_data, write_path, format)
    @ugoira_file = ugoira_file
    @frame_data = frame_data
    @write_path = write_path
    @format = format
  end

  def process!
    folder = Zip::File.open_buffer(@ugoira_file)

    if format == :gif
      write_gif(folder)
    elsif format == :webm
      write_webm(folder)
    elsif format == :apng
      write_apng(folder)
    end
  end

  def write_gif(folder)
    anim = Magick::ImageList.new
    delay_sum = 0
    folder.each_with_index do |file, i|
      image_blob = file.get_input_stream.read
      image = Magick::Image.from_blob(image_blob).first
      image.ticks_per_second = 1000
      delay = @frame_data[i]["delay"]
      rounded_delay = (delay_sum + delay).round(-1) - delay_sum.round(-1)
      image.delay = rounded_delay
      delay_sum += delay
      anim << image
    end

    anim = anim.optimize_layers(Magick::OptimizeTransLayer)
    anim.write("gif:" + write_path)
  end

  def write_webm(folder)
    Dir.mktmpdir do |tmpdir|
      FileUtils.mkdir_p("#{tmpdir}/images")
      folder.each_with_index do |file, i|
        path = File.join(tmpdir, "images", file.name)
        image_blob = file.get_input_stream.read
        File.open(path, "wb") do |f|
          f.write(image_blob)
        end
      end

      # Duplicate last frame to avoid it being displayed only for a very short amount of time.
      last_file_name = folder.to_a.last.name
      last_file_name =~ /\A(\d{6})(\.\w{,4})\Z/
      new_last_index = $1.to_i + 1
      file_ext = $2
      new_last_filename = ("%06d" % new_last_index) + file_ext
      path_from = File.join(tmpdir, "images", last_file_name)
      path_to = File.join(tmpdir, "images", new_last_filename)
      FileUtils.cp(path_from, path_to)

      delay_sum = 0
      timecodes_path = File.join(tmpdir, "timecodes.tc")
      File.open(timecodes_path, "w+") do |f|
        f.write("# timecode format v2\n")
        @frame_data.each do |img|
          f.write("#{delay_sum}\n")
          delay_sum += img["delay"]
        end
        f.write("#{delay_sum}\n")
        f.write("#{delay_sum}\n")
      end

      ext = folder.first.name.match(/\.(\w{,4})$/)[1]
      system("ffmpeg -i #{tmpdir}/images/%06d.#{ext} -codec:v libvpx -crf 4 -b:v 5000k -an #{tmpdir}/tmp.webm")
      system("mkvmerge -o #{write_path} --webm --timecodes 0:#{tmpdir}/timecodes.tc #{tmpdir}/tmp.webm")
    end
  end

  def write_apng(folder)
    Dir.mktmpdir do |tmpdir|
      folder.each_with_index do |file, i|
        frame_path = File.join(tmpdir, "frame#{"%03d" % i}.png")
        delay_path = File.join(tmpdir, "frame#{"%03d" % i}.txt")
        image_blob = file.get_input_stream.read
        delay = @frame_data[i]["delay"]
        image = Magick::Image.from_blob(image_blob).first
        image.format = "PNG"
        image.write(frame_path)
        File.open(delay_path, "wb") do |f|
          f.write("delay=#{delay}/1000")
        end
      end
      system("apngasm -o -F #{write_path} #{tmpdir}/frame*.png")
    end
  end
end
