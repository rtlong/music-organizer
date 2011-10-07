#!/usr/bin/env ruby

require 'rubygems'
require 'taglib'

file = TagLib::MPEG::File.new(ARGV.join)
tag = file.id3v2_tag


puts "'#{tag.title}' by #{tag.artist}"