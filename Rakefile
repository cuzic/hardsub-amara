require 'json'
require 'pp'

def rule2 hash
  target, sources = hash.to_a.first

  rule target => (lambda do |t|
    sources.flatten.map do |source|
      src = t.gsub(target, source)
      if src.end_with?("/") then
        dir = src.gsub(%r(/$), "")
        directory dir
        dir
      else
        src
      end
    end
  end) do |t|
    yield t
  end
end

def curl *args
  json = open("config.json").read
  json = JSON(json)

  headers = %W(
 -H 'X-api-username: #{json["username"]}'
 -H 'X-apikey: #{json["apikey"]}'
   ).join(" ")
  case args.length
  when 1
    path = args.first
    JSON(`curl -o - #{headers} 'https://www.amara.org/api2/partners/#{path}'`)
  when 2
    filename, path = *args
    sh "curl -o #{filename} #{headers} 'https://www.amara.org/api2/partners/#{path}'"
  end
end

def skip filename
  STDERR.puts "fail #{filename}"
  File.unlink(filename)
end

def is_successfully_downloaded? filename
  unless File.file?(filename)
    return false
  end

  body = open(filename).read
  case
  when body.size < 4
    return false
  when body.include?("504 Gateway Time-out")
    return false
  when body.include?("502 Bad Gateway")
    return false
  when filename.end_with?(".json") && JSON(body)["objects"].nil?
    return false
  end
  return true
end

desc "download json files from amara.org"
task :setup do
  0.step(500_000, 20) do |i|
    Rake::Task["json/#{i}.json"].invoke
  end
end

directory "json"

rule %r(json/\d+.json) => "json" do |t|
  path = t.name.gsub(%r(^json/(\d+).json$), "videos/?offset=\\1")
  curl t.name, path
end

desc "download subtitles from amara.org only if the movie has both Japanese and English subtitles"
task :download_sub do |t|
  Dir.glob("json/*.json") do |filename|
    unless is_successfully_downloaded? filename then
      File.unlink filename
      next
    end

    json = open(filename).read
    json["objects"].each do |o|
      langs = o["languages"]
      if langs.any?{|t| t["code"] == "ja"} and
        langs.any?{|t| t["code"] == "en"} then
        ass = "ass/#{o["id"]}.ass"
        Rake::Task[ass].invoke
      end
    end
  end
end

directory "srt"
def download_srt target, lang
  id = target[%r(srt/(\w+)-#{lang}.srt),1]
  path = "videos/#{id}/languages/#{lang}/subtitles/?format=srt"
  curl target, path
end

rule %r(srt/(\w+)-ja.srt) => "srt" do |t|
  download_srt t.name, "ja"
end

rule %r(srt/(\w+)-en.srt) => "srt" do |t|
  download_srt t.name, "en"
end

def redownload file
  2.times do
    if is_successfully_downloaded? file then
      return true
    else
      File.unlink file if File.file?(file)
      sh "rake #{file}"
      if is_successfully_downloaded? file then
        return true
      end
    end
  end
  return false
end

directory "ass"
rule2 %r(ass/(\w+).ass) => %w(
  srt/\\1-en.srt srt/\\1-ja.srt ass/
) do |t|
  target = t.name
  en, ja, = t.sources
  if redownload en and redownload ja then
    cmdline = "ruby srt2ass.rb #{en} #{ja} #{target}"
    sh cmdline
  end
end

desc "download youtube flv's with Japanese/English subtitles"
task :"youtube-dl" do
  Dir.glob("ass/*.ass") do |filename|
    id = file.basename(filename, ".ass")
    rake::task["youtube/#{id}/.flv"].invoke
  end
end

desc "reencode youtube flv's with hardsubbed Japanese/English subtitles"
task :"hardsub" do
  Dir.glob("srt/*-ja.srt").each_with_object [] do |janame, ary|
    ja_size = File.size(janame)
    enname = janame.gsub("ja", "en")
    if File.file? enname and
      File.size(enname) > 2000 and 
      File.size(janame) > 2000 then
      en_size = File.size(enname) 
      ary << [janame, ja_size.to_f / en_size]
    end
  end.sort_by {|fname, size| -size }.each do |fname, size|
    id = fname[%r(srt/(.+)-ja.srt), 1]
    Rake::Task["hardsub/#{id}/.avi"].invoke
  end
end

rule2 %r(youtube/(\w+)/.flv) => %w(
  youtube/ youtube/\\1/
) do |t|
  _, dir = t.sources
  p dir
  if Dir.glob("#{dir}/*.flv").size < 1 then
    path = dir.gsub("youtube/", "videos/") + "/"
    json = curl path
    if urls = json["all_urls"] then
      url = urls.first
      unless url.nil? or
        url.include?("mozilla.net") then
        Dir.chdir dir do
          commandline = "youtube-dl --write-info-json #{url} --restrict-filenames"
          begin
            sh commandline
          rescue 
            $stderr.puts $!
          end
        end
      end
    end
  end
end

rule2 %r(hardsub/(\w+)/.avi) => %w(
  ass/\\1.ass youtube/\\1/.flv hardsub/\\1/
) do |t|
  _, flv, dir = t.sources
  glob = flv.gsub(".flv", "*.flv")
  flv = Dir.glob(glob).first

  unless flv.nil? then
    unless flv.end_with? "error.flv" then
      target = flv.gsub("youtube", "hardsub").gsub(".flv", ".avi")
      unless File.file? target then
        ass, = t.sources
        combine target, flv, ass
      end
    end
  end
end

def combine target, original, ass
  options = {
    :source => original,
    :output => target,
    :of => "lavf",
    :"ass-line-spacing" => "0",
    :subcp => "utf-8",
    :"subfont-text-scale" => "3",
    :sub => ass,

    :vf => "dsize=480:320:2,scale=-8:-8,expand=480:320::0:1,harddup",

    :oac => "mp3lame",
    :ovc => "xvid",
    :xvidencopts => "fixed_quant=4:autoaspect"
    
    #:lavfopts => "format=mp4:o=absf=aac_adtstoasc",
    #:oac => "faac",
    #:ovc => "x264",
    #:x264encopts => %w(preset=ultrafast tune=film crf=27 frameref=7
    #                   threads=auto global_header).join(":")

    #:lavfopts => "format=mp4:o=absf=aac_adtstoasc",
    #:oac => "lavc",
    #:lavcopts => "acodec=libfaac:abitrate=32768:o=absf=aac_adtstoasc",
    #:x264encopts => %w(preset=ultrafast tune=film crf=27 frameref=7
    #                   threads=auto global_header).join(":")
  }

  if ENV["DEBUG"] then
    options.merge!({
      :ss => "00:00:20",
      :endpos => "10",
    })
  end

  mencoder options
end

def mencoder options
  source = options.delete :source
  filename = options.delete :output

  argument = options.map do |key,value|
    " -#{key} #{value}"
  end.join("\\\n")

  if File.file? filename then
    STDERR.puts "#{filename} already exists!"
    return
  end

  if filename then
    filename = "-o #{filename}"
  else
    filename = ""
  end
  cmdline = "mencoder #{source} #{filename} \\\n#{argument}"
  #  puts cmdline; exit
  sh cmdline
end

