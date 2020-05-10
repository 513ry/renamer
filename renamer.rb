#!/usr/bin/env ruby
# siery (c) 2020-present
# This script will swap PATTERN for the PHRASE in PROJECT_ROOT directory. It's
# designed to be safe and fast for large data bases.
#
# TODO:
# - Integrate with projectile. Just on the *.project file finding level, no need
#   for other integration as you can always do: rename --path `projectile path
#   my_project`
#
# BUGS:
# - File content is NOT omitted when read_pattern returns key:5 (FIXED)

require 'io/console'
require 'colorize'
require 'readline'

# Change this string when adding a new user option
module Renamer
  OPTIONS = 'fin'

  # Set ROOT file/directory
  if ARGV[0] and File.file?(ARGV[0]) || File.directory?(ARGV[0])
    ROOT = ARGV[0]
  else
    ROOT = '.'
  end

  @flags = ''
  @do_search_content = true
  @do_search_names = false

  def self.getline prompt
    while buffer = Readline.readline(prompt, true)
      p Readline::HISTORY.to_a
      return buffer
    end
  end

  def self.yes_or_no msg
    print msg
    print " [y/n] "
    while (c = STDIN.getch) != 'y' do
      yiled c if c == 'n'
    end
    puts ''
  end

  def self.gen_flag

  end

  def self.no_options?
    @no_options ||= false
  end

  def self.no_options=(other)
    @no_options ||= false
  end

  # Read PATTERN (recursive)
  # Here is the excuse for the response table:
  # 0 = no options
  # 1 = insensitive
  # 2 = change file content and names
  # 3 = insensitive including file names
  # 4 = change file names only
  # 5 = insensitive excluding file content
  # Edit: This method seems to chunky to me, try to avoid those ifs
  def self.read_pattern
    pattern = getline "Enter a pattern: "
    index = 0

    opt = (/[#{OPTIONS}]?[#{OPTIONS}]?[#{OPTIONS}]\s?/.match(pattern[2..5])).to_s
    ret = Hash.new { |value, key| value[key] = pattern[(opt.size + 2)..-1] }

    # If something like a argument is found then check if it comfirms:
    # - white space is required at the end of argument execution,
    # - part after matches any aviable option pattern.
    if (/--[a-z]?[a-z]?[a-z]\s?/.match(pattern))
      ws = opt.chomp[-1].freeze
      if ws != " " && opt != ''
        puts "No white space found."
        retape = true
      elsif opt.size == 3 && /[ni]/.match(opt[0]) && /[ni]/.match(opt[1]) && opt[0] != opt[1]
        ret[3]
      elsif opt.size == 3 && /[nf]/.match(opt[0]) && /[nf]/.match(opt[1]) && opt[0] != opt[1]
        ret[4]
      elsif opt.size > 3 && opt[0] != opt[1] && opt[3] != opt[0..1]
        ret[5]
      elsif opt[0] == 'i'
        ret[1]
      elsif opt[0] == 'n'
        ret[2]
      else
        retape = true
      end
    else
      ret[0]
    end

    if retape
      yes_or_no "'#{pattern[0..3]}' seems to be a broken argument. Retape?" do |c|
        ret[0]
        break
      end
      
      read_pattern
    end
    
    index += 1
    ret
  end

  def self.search_content pattern
    puts "searching content.."
    file_list = []
    # This register helps to skip duplicates
    reg_path = String.new
    # Some handy regexes for you and your family
    regx_node = /.*:\d{1,}:/.freeze
    regx_num  = /:\d{1,}:$/.freeze

    @flags != '' and @flags.insert(0, '-')
    
    # Identify files which needs to be changed
    raw_list = %x{ag #{@flags} #{pattern} #{ROOT} --nogroup 2> /dev/null}.scan(regx_node)
    # Format raw_list to file_tree
    raw_list.each_with_index do |node, index|
      path = node.to_s.chomp(node.match(regx_num).to_s)
      # Add path to FILE_TREE when new name occurred
      if index
        if (path != reg_path || raw_list[index] == nil)
          file_list.push path
        end
      end
      reg_path = path
    end
    # Check if AG did return any files
    if file_list[0] == nil
      puts "Not found."
      false
    end
    file_list
  end

  def self.search_names pattern
    puts "searching names.."
    # Identify files which needs to be changed
    file_list = %x{find #{ROOT} -#{@flags}name #{pattern}}.scan(/.+\n?/)
    file_list.each do |file|
      file.chomp!
    end

    file_list
  end

  def self.swap_words phrase, file_list
    @do_search_names = false
    
    if @do_search_content
      # Swapping words in files by using gsub
      file_list.each_with_index do |path, index|
        if path == "\n"
          @do_search_names = true
          break
        end
        
        content = File.read(@path)
        File.open(path, w) do |file|
          file << file.gsub(content, phrase)
          puts "'#{file_list[index]}' been changed."
        end
      end
    end
    if @do_search_names
      
    end
  end

  def self.run!
    puts "renaming file at #{File.absolute_path(ROOT)}.."

    # Set flag string and individual option @flags
    pattern = read_pattern
    status  = pattern.keys.first
    pattern = pattern.values.first

    # Read PHRASE
    phrase = getline "Enter a phrase: "

    # Map read_pattern response table to @flags.
    (status == 2 || status == 3 || status == 4 || status == 5) and @do_search_names = true
    (status == 1 || status == 3 || status == 5) and  @flags += 'i'
    (status == 4 || status == 5) and @do_search_content = false

    # Search files content and return list of files if pattern matches
    # else create an empty array
    file_list = []

    if @do_search_names
      file_list = search_names(pattern) || []
      # New line element indicats end of file content's list changes
      @do_search_content and file_list.insert(-1, "\n")
    end

    if @do_search_content
      file_list.insert(-1, search_content(pattern) || '')
    end

    # replace with file_list.print method
    puts "Name changes".green if @do_search_names
    puts "Content changes:".green if !@do_search_names
    file_list.each do |file|
      if file != "\n"
        puts file
      else
        puts "Content changes:".green
      end
    end

    # Ask user to approve the changes
    yes_or_no "The above files will be changed. Do you approve this action?" do
      exit 2
    end

    puts "#{phrase}, #{file_list}"

    swap_words phrase, file_list
  end
end

Renamer.run!

