#!/usr/bin/env ruby
require 'securerandom'
require 'optparse'
require 'ostruct'
require 'stringio'


DLM = '/'  # Token delimiter
DEFAULTS = {
  wordlist: File.join(__dir__, 'eff_large_wordlist.txt'),
  symbols: "!@#$%^&*-_=+;:'\",./<>?~",
  format: "(#{DLM}w )*6",
  count: 1
}

# https://stackoverflow.com/questions/2650517/count-the-number-of-lines-in-a-file-without-reading-entire-file-into-memory
def file_nb_lines(filename)
  File.foreach(filename).reduce(0) {|acc, line| acc += 1}
end

def pick_random_word(wordlist)
  File.open(wordlist, 'r') {|file|
    # Pick a random number N then read N lines from the file
    random_index = SecureRandom.random_number(file_nb_lines wordlist)
    random_index.times { file.readline }
    # Return the next line
    file.readline.split("\t")[1].strip
  }
end

def random_element_in_array(array)
  array[SecureRandom.random_number(array.length)]
end

def parse_command_line(args)
  options = OpenStruct.new
  options.format   = DEFAULTS[:format]
  options.wordlist = DEFAULTS[:wordlist]
  options.symbols  = DEFAULTS[:symbols]
  options.count    = DEFAULTS[:count]
  options.excluded = ""

  opt_parser = OptionParser.new {|opts|
    opts.banner = <<~DOCBANNER
      Usage: #{File.basename($0)} [options] <format>

      <format>: Specify the format of the generated passphrase (default\: "#{options.format}")
      Available tokens are:
        #{DLM}w => a word from the wordlist
        #{DLM}d => a digit [0-9]
        #{DLM}s => a symbol from the string SYMBOLS
        #{DLM}S => a symbol or a digit
        #{DLM}a => a random character (letter digit or symbol)
      Example: "pass#{DLM}d#{DLM}d#{DLM}d_#{DLM}w" yields "pass107_recopy"

      Tokens or groups of tokens can be repeated using the syntax ()*N 
      where N is the amount of repetitions.
      Example: "(#{DLM}w#{DLM}d)*3" yields "faster4employer0rectified3"
    DOCBANNER
    opts.separator ""
    opts.separator "Options:"

    opts.on("-w path/to/wordlist",
        "Pick words from the specified wordlist",
        "\t(default: #{options.wordlist})") do |list|
      options.wordlist = list
    end

    opts.on("-s symbols",
        "Specify a string of symbols to pick from",
        "\t(default: #{options.symbols})") do |list|
      options.symbols = list
    end

    opts.on("-e symbols",
        "Exclude one or more symbols") do |list|
      options.excluded = list
    end

    opts.on("-c N",
        "Number of passphrases to generate") do |count|
      options.count = count.to_i
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
  }
  opt_parser.parse!(args)

  # Parse the remaining non-option arguments which should be the format string
  if args.length == 1
    options.format = args.last.dup
  elsif args.empty?
    puts "WARNING: No format provided! Using default format.\n",
    "See --help for more information.\n\n"
  else
    puts opt_parser
    exit
  end

  options
end


options = parse_command_line(ARGV)
format = options.format
symbols = options.symbols.delete(options.excluded)
tokens = {
  'w' => lambda { pick_random_word(options.wordlist) },
  'd' => lambda { SecureRandom.random_number(10).to_s },
  's' => lambda { random_element_in_array(symbols) },
  'S' => lambda {
    full_list = ('0'..'9').to_a + symbols.chars
    random_element_in_array(full_list)
  },
  'a' => lambda {
    # Concat digits, letters and symbols into a single array
    full_list = ('0'..'9').to_a + ('a'..'z').to_a + ('A'..'Z').to_a + symbols.chars
    random_element_in_array(full_list)
  }
}

# Replace all "*n" in format string
# example: '(/w)*3' => '/w/w/w'
preprocessing = /(#{DLM}\w|\([#{DLM}\w\s]*\))\*(\d+)/
while format.match(preprocessing) {|m|
  token = m[1].to_s
  # strip surrounding parentheses
  if token[0] == '(' && token[-1] == ')'
    token = token.slice(1 ... -1)
  end
  # Replace from <beginning of match> to <end of match>
  # with the token copied n times
  format[m.begin(0) ... m.end(0)] = token * m[2].to_i
}
end

# Generate <count> passphrases
options.count.times do
  # Replace all tokens in the format string with their random value
  # and display the result
  token_regex = /#{DLM}[#{tokens.keys.join}]/
  puts format.gsub(token_regex) {|m|
    tokens[m[1]].call
  }
end
