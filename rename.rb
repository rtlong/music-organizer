#!/usr/bin/env ruby

require 'rubygems'
require 'id3lib'

puts "Looking for MP3s..."

# Some arrays for a report at the end:
MISSING_MP3 = {}
MISSING_CDG = {}

begin
  undo_file = File.new('undo.sh', 'w')

  undo_file.puts <<-"HELP".gsub(/^\s+/, '')
  # You can use this file to revert the changes made by #{__FILE__}
  HELP

  def clean_title(title)
    title.strip.
          squeeze(' ').
          gsub(': ', ' - ').     # replace 'Star Wars IV: Return of the Jedi' with '...IV - Return...'
          delete('?*\|').        # delete these chars
          tr('<^>":', '_').      # replace these with underscore: <^>":
          gsub(/\s+/,' ').       # squish multiple spaces together
          squeeze('_').          # squish multiple underscores
          gsub(/^[^A-Za-z0-9'$(\[]+/, '').  # Remove extra crap from the start
          gsub(/[^A-Za-z0-9'.$!)\]]+$/, '') # Remove extra crap from the end
  end

  files = Dir.glob('**/*.*')
  filenames = files.group_by {|filename| %r<^(.+)\..+?$>.match(filename)[1] }

  puts "Found #{files.length} files representing #{filenames.length} unique titles.\n"

  max_name_length = filenames.keys.collect(&:length).max

  filenames.each_pair do |name, files|
    dir = File.dirname(files.first) # grab the directory from one of the files
    files = Hash[files.collect { |f| [File.extname(f).downcase.delete('.').to_sym, f] }]

    # show which name we're looking at
    print "#{files.count}x: '#{name}.*' -> "

    unless files.has_key? :cdg then
      MISSING_CDG[name] = files.values
      puts "Error - see below..."
      next
    end

    unless files.has_key? :mp3 then
      MISSING_MP3[name] = files.values
    else
      tags = ID3Lib::Tag.new(files[:mp3])

      # Grab the ID3 tag info (artist / title)
      new_name = clean_title("#{tags.artist.split( %r(\s*/\s*) ).join('; ')} - #{tags.title}")

      dup_counter = nil
      naming_conflict = true # set true so we enter the while loop

      # Check for naming conflicts for all files together, glean a dup_counter that we'll append to the filename in cases where we have conflicts
      while naming_conflict do
        # use a .0, .1, .2 ... suffix when there are naming conflicts
        naming_conflict = nil
        files.each_pair do |ext, f|
          new_f = File.join(dir, [new_name, dup_counter, ext.to_s].compact.join("."))

          # only check for conflicts if this isn't the present name of the file...
          naming_conflict = true if new_f != f and File.exists?(new_f)
        end

        dup_counter = dup_counter.nil? ? 0 : (dup_counter + 1) if naming_conflict
      end

      print "'#{[new_name, dup_counter].compact.join('.')}' ..."

      # Perform the renames
      files.each_pair do |ext, f|
        new_f = File.join(dir, [new_name, dup_counter, ext.to_s].compact.join(".") )
        if new_f != f then
          raise RuntimeError, "WTF!" if File.exists?(new_f)

          # write this change to the undo script
          #undo_file.puts %(mv -v "#{new_f}" "#{f}")

          File.rename(f, new_f)
          print " #{ext.to_s}"
        end
      end
    end
    puts
  end
ensure
  undo_file.close
end

if MISSING_MP3.length > 0 then
  puts "\n\nThere were some files found that have no MP3 by the same name:"
  puts MISSING_MP3.values.flatten.collect{|f| %Q("#{f}")}.join(' ')
end

if MISSING_CDG.length > 0 then
  puts "\n\nThere were some files found without a corresponding CDG file:"
  puts MISSING_CDG.values.flatten.collect{|f| %Q("#{f}")}.join(' ')
end

