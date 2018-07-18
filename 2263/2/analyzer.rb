require 'russian_obscenity'
require 'active_support/all'

# Counts battles and rounds, can take name of one rappe
class BattlesAnalyzer
  attr_reader :paths, :name
  attr_reader :list

  def initialize(name = nil)
    @paths = Dir[__dir__ + '/texts/*'] # Path to directory with texts convertes to array of paths to each file
    @name = name
  end

  def path=(new_path)
    @paths = Dir[new_path + '/*']
  end

  # :reek:TooManyStatements
  def rounds
    list = {}
    @paths.each do |path|
      name_in_file = get_name_in_file(path)
      explore_file(name_in_file, list) { count_rounds(path) } if !@name || name_in_file == @name
    end
    list
  end

  def battles
    list = {}
    @paths.each do |path|
      name_in_file = get_name_in_file(path)
      add_entry_to_list(name_in_file, 1, list) if !@name || name_in_file == @name
    end
    list
  end

  private

  def get_name_in_file(path)
    name_in_file = path.match(%r{(?<=/texts/\s).*?((?=\s+против\s+)|(?=\s+VS\s+)|(?=\s+vs\s+))}).to_s
    raise AnalyzerTextNameError, path if name_in_file == ''
    name_in_file
  end

  def explore_file(name_in_file, list)
    value = 0
    value = yield if block_given? # Takes block which counts nessesary value
    add_entry_to_list(name_in_file, value, list)
  end

  def add_entry_to_list(name, number, list)
    name = name.to_sym
    list[name] = list.key?(name) ? list[name] + number : number
    list
  end

  # :reek:TooManyStatements
  def count_rounds(path)
    rounds_counter = 0
    file = File.open(path)
    file.each do |line|
      words = to_word_array(line)
      rounds_counter += 1 if round_description?(words)
    end
    rounds_counter.zero? ? 1 : rounds_counter
  end

  def to_word_array(line)
    words = line.split(/[^[[:word:]]\*]+/)
    words
  end

  # Check if the line is round description
  def round_description?(words)
    return true if !words[1].to_i.zero? && words[0] =~ /(Р|р)аунд/
    return true if !words[0].to_i.zero? && words[1] =~ /(Р|р)аунд/
    false
  end
end

# Counts words and bad words, can take name of one rapper
class WordsAnalyzer < BattlesAnalyzer
  attr_reader :paths, :name
  attr_reader :list

  def initialize(name = nil)
    @paths = Dir[__dir__ + '/texts/*'] # Path to directory with texts convertes to array of paths to each file
    @name = name
  end
  
  # :reek:TooManyStatements
  def words
    list = {}
    @paths.each do |path|
      name_in_file = get_name_in_file(path)
      list = explore_file(name_in_file, list) { count_words(path) } if !@name || name_in_file == @name
    end
    list
  end

  # :reek:TooManyStatements
  def bad_words
    list = {}
    @paths.each do |path|
      name_in_file = get_name_in_file(path)
      list = explore_file(name_in_file, list) { count_bad_words(path) } if !@name || name_in_file == @name
    end
    list
  end

  private

  # :reek:TooManyStatements
  def count_words(path)
    words_counter = 0
    file = File.open(path)
    file.each do |line|
      words = to_word_array(line)
      words_counter += words.size unless round_description?(words)
    end
    words_counter
  end

  # :reek:TooManyStatements
  def count_bad_words(path)
    bad_words_counter = 0
    file = File.open(path)
    file.each do |line|
      words = to_word_array(line)
      bad_words_counter = check_obscenity(words, bad_words_counter) unless round_description?(words)
    end
    bad_words_counter
  end

  def check_obscenity(words, counter)
    words.each do |word|
      counter += 1 if RussianObscenity.obscene?(word) || word.match(/.*\*.*/)
    end
    counter
  end
end

# Makes hash which contains each using word and number of it's reiteration, can take name of one rapper
class EachWordAnalyzer < BattlesAnalyzer
  attr_reader :paths, :name
  attr_reader :list

  def initialize(name = nil)
    @paths = Dir[__dir__ + '/texts/*'] # Path to directory with texts convertes to array of paths to each file
    @name = name
  end

  # :reek:TooManyStatements
  def each_word
    list = {}
    @paths.each do |path|
      name_in_file = get_name_in_file(path)
      list = explore_file(name_in_file, list) { count_each_word(path) } if !@name || name_in_file == @name
    end
    list
  end

  private

  def add_entry_to_list(name, words_hash, list)
    name = name.to_sym
    list[name] = list.key?(name) ? merge_with_sum(list[name], words_hash) : words_hash
    list
  end

  # Works like Hash#merge, but summarize values of repeated keys
  def merge_with_sum(first_hash, second_hash)
    second_hash.each_key do |key|
      first_hash.key?(key) ? first_hash[key] += second_hash[key] : first_hash.merge(key => second_hash[key])
    end
    first_hash
  end

  def handle_word_array(words, words_hash)
    words.each do |word|
      word = to_lower(word).to_sym
      words_hash[word] = words_hash.key?(word) ? words_hash[word] + 1 : 1
    end
    words_hash
  end

  # :reek:TooManyStatements
  def count_each_word(path)
    words_hash = {}
    file = File.open(path)
    file.each do |line|
      words = to_word_array(line)
      words_hash = handle_word_array(words, words_hash) unless round_description?(words)
    end
    words_hash
  end

  # Downcase russian symbols
  def to_lower(word)
    word.mb_chars.downcase!.to_s
  end
end

# Exception that is raised if text file doesn't match name pattern
class AnalyzerTextNameError < StandardError
  def initialize(path, message = nil)
    @file = path
    message ? @message = default_message : @message = message
  end

  private

  def default_message
    "Error. Name of #{@file} doesn't match to pattern (<name> VS/Против)"
  end
end
