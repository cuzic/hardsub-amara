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

directory "json"
rule %r(json/\d+.json) => "json" do |t|
  offset = t.name[%r(json/(\d+).json),1]
  puts offset
  path = "videos/?offset=#{offset}"
  curl t.name, path
end

task :setup do
  0.step(500_000, 20) do |i|
    Rake::Task["json/#{i}.json"].invoke
  end
end

def skip filename
  STDERR.puts "fail #{filename}"
  File.unlink(filename)
end

task :download_sub do |t|
  Dir.glob("json/*.json") do |filename|
    body = open(filename).read
    if body.size < 4 then
      File.unlink filename
      next
    end
    if body =~ /504 Gateway Time-out|502 Bad Gateway/ or
      (json = JSON(body))["objects"].nil? then
      skip filename
      next
    end

    json["objects"].each do |o|
      langs = o["languages"]
      if langs.any?{|t| t["code"] == "ja"} and
        langs.any?{|t| t["code"] == "en"} and

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
    if !File.file?(file) or
      open(file).read.include?("502 Bad Gateway") or
      File.size(file) < 10 then
      File.unlink file if File.file?(file)
      sh "rake #{file}"
    else
      return true
    end
  end
  File.unlink file if File.file?(file)
  return false
end

directory "ass"
rule2 %r(ass/(\w+).ass) => [
  "srt/\\1-en.srt",
  "srt/\\1-ja.srt",
  "ass/"
] do |t|
  target = t.name
  en, ja, = t.sources
  if redownload en and redownload ja then
    cmdline = "ruby srt2ass.rb #{en} #{ja} #{target}"
    sh cmdline
  end
end

task :"youtube-dl" do
  Dir.glob("ass/*.ass") do |filename|
    id = file.basename(filename, ".ass")
    rake::task["youtube/#{id}/.mp4"].invoke
  end
end

task :"hardsub" do
  Dir.glob("srt/*-ja.srt").map do |janame|
    ja_size = File.size(janame)
    enname = janame.gsub("ja", "en")
    if File.file? enname and
      File.size(enname) > 2000 and 
      File.size(janame) > 2000 then
      en_size = File.size(enname) 
      #[janame, ja_size.to_f / en_size]
      [janame, File.size(enname)]
    else
      nil
    end
  end.select{|t| t}.sort_by {|fname, size| -size }.each do |fname, size|
    id = fname[%r(srt/(.+)-ja.srt), 1]
    Rake::Task["hardsub/#{id}/.mp4"].invoke
  end
end

rule2 %r(youtube/(\w+)/.mp4) => [
  "youtube/", "youtube/\\1/"
] do |t|
  id = t.name[%r(youtube/(\w+)/.mp4), 1]
  dir = "youtube/#{id}"
  if Dir.glob("#{dir}/*.flv").size < 1 then
    path = "videos/#{id}/"
    json = curl(path)
    if urls = json["all_urls"] then
      url = urls.first
      unless url.nil? or
        url.include?("mozilla.net") then
        Dir.chdir dir do
          commandline = "youtube-dl --write-info-json #{url} --restrict-filenames"
          begin
            sh commandline
          rescue
          end
        end
      end
    end
  end
end

rule2 %r(hardsub/(\w+)/.mp4) => [
  "ass/\\1.ass",
  "youtube/\\1/.mp4",
  "hardsub/\\1/"
] do |t|
  _, mp4, dir = t.sources
  glob = mp4.gsub(".mp4", "*.flv")
  flv = Dir.glob(glob).first

  unless flv.nil? then
    target = flv.gsub("youtube", "hardsub").gsub(".flv", ".mp4")
    unless File.file? target then
      ass, = t.sources
      combine target, flv, ass
    end
  end
end

def combine target, original, ass
  options = {
    :source => original,
    :output => target,
    #:vf => "dsize=480:352:2,scale=-8:-8,harddup",
    :vf => "dsize=480:320:2,scale=-8:-8,expand=480:320::0:1,harddup",
    :of => "lavf",
    #:lavfopts => "format=mp4",
    :oac => "mp3lame",
    #:oac => "lavc",
    #:lavcopts => "acodec=libfaac",
    :ovc => "x264",
    :"ass-line-spacing" => "0",
    :subcp => "utf-8",
    :"subfont-text-scale" => "3",
    :sub => ass,
    :x264encopts => <<X264.chomp,
    preset=ultrafast:tune=film:crf=27:frameref=7:threads=auto
X264
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

