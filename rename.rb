#!/usr/bin/env ruby

require 'rubygems'
require 'id3lib'

puts "Looking for MP3s..."

# Some arrays for a report at the end:
MISSING_MP3 = {}
MISSING_CDG = {}

begin
  undo_file = File.new('undo.sh', 'w')

  undo_file.puts <<-"HELP"
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
  filenames = files.group_by {|filename| /([^\/]+)\..+?$/.match(filename)[1] }

  puts "Found #{files.length} files representing #{filenames.length} unique titles.\n"

  max_name_length = filenames.keys.collect(&:length).max

  filenames.each_pair do |name, files|
    # show which name we're looking at
    print "#{files.length}x: '#{name}.*' -> "

    cdg_files = files.select{|f| f =~ /.*\.cdg/i }
    if cdg_files.empty? then
      MISSING_CDG[name] = files
      puts "Error - see below..."
      next
    end

    mp3_files = files.select{|f| f =~ /.*\.mp3/i }
    if mp3_files.empty? then
      MISSING_MP3[name] = files
    else
      tags = ID3Lib::Tag.new(mp3_files.first)

      # Grab the ID3 tag info (artist / title)
      new_name = clean_title("#{tags.artist.split( %r(\s*/\s*) ).join('; ')} - #{tags.title}")

      # rename the files, but only if new_name is set and is different than the original title
      if ( not new_name.empty? ) and new_name != name then
        dup_counter = nil
        naming_conflict = nil # nil to signify that we don't know

        # Check for naming conflicts for all files together
        until naming_conflict == false do
          # use a .0, .1, .2 ... suffix when there are naming conflicts
          conflicts = files.collect do |f|
            ext = File.extname(f).delete('.')
            dir = File.dirname(f)

            File.exists?(new_f = File.join(dir, [new_name, dup_counter, ext].compact.join(".") ))
          end

          naming_conflict = conflicts.include?(true) and dup_counter = dup_counter.nil? ? 0 : (dup_counter + 1)
        end

        print "'#{[new_name, dup_counter].compact.join('.')}' ..."

        # Perform the renames
        files.each do |f|
          ext = File.extname(f).delete('.')
          dir = File.dirname(f)

          new_f = File.join(dir, [new_name, dup_counter, ext].compact.join(".") )
          raise RuntimeError, "WTF!" if File.exists?(new_f)

          # write this change to the undo script
          undo_file.puts %(mv -v "#{new_f}" "#{f}")

          File.rename(f, new_f)
          print " #{ext}"
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

