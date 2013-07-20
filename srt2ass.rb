#!/usr/bin/ruby
# coding: utf-8
require "pp"
require "titlekit"

module Titlekit
  class MergeJob < Job
    def add_space str
      str.gsub(/[、。」）．，]/,'\& ').
        gsub(/\G.*?[0-9a-zA-Z]+/,'\& ').
        gsub(/\G.*?[^\s]{13}/,'\& ')
    end

    def polish want
      super
      ary = []
      prev = nil
      want.subtitles.each_cons(2) do |fst, snd|
        if fst[:start] == snd[:start] and
          fst[:end] == snd[:end] then
          en_ja = [fst, snd].sort_by do |t|
            t[:track]
          end
          hash = en_ja.first
          ja = en_ja[1]
          ja[:lines] = add_space ja[:lines]
          hash[:lines] = en_ja.map{|t|
            t[:lines].gsub("\n"," ")
          }.join("\n")
          prev = snd
          ary << hash
        elsif prev != fst
          if fst[:track].include?("ja") then
            fst[:lines] = add_space fst[:lines]
          end
          ary << fst
        end
      end
      want.subtitles = ary
    end
  end
end

def main
  job = Titlekit::MergeJob.new
  output = ARGV.pop
  ARGV.each do |filename|
    job.have { file(filename) }
  end
  job.want { file(output) }
  unless job.run then
    puts job.report.join("\n")
  end
end

if $0 == __FILE__ then
  main
end
