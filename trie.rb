# -*- coding: utf-8 -*-
#
# TODO: node should really be equivalent to a trie, so a subtree can use trie methods...
# TODO: rework lookup using completion()-like routine?
# TODO: add each method (other enumerables?)
# TODO: add delete method


# Randy Fischer (rf@ufl.edu) reimplemented this wheel on 2010-06-13.  Pleasant exercise.
#
# Build a trie (a kind of sorted hash) - my initial goal was to find
# the largest common prefix from a list of strings.  This also does
# the usual trie tricks: stores key/value pairs, orders the keys,
# searchs for all substrings given a match pattern, etc.

class Trie

  # Box let's us put a value into a box, then get it out of the box.
  # We need this because we'd like to store nil and false values on
  # a node slot.  So a slot can have one of two values: nil (meaning
  # no value), or a box (with some value in it, including nil).

  class Box

    attr_reader :value

    def initialize thing
      @value = thing
    end

    def unwrap
      value
    end

    def to_s
      "#<box##{self.object_id}: #{value.inspect}>"
    end
  end

  # A node stores a single character, pointers to children nodes, and perhaps a boxed value.
  #
  # Example Node: < letter => 'a', value => 'adjective, also the indefinite article, refers...', children => [ <node>, <node> .. ] >

  class Node

    attr_reader   :letter, :children
    attr_accessor :value

    def initialize letter = ''
      @letter     = letter
      @children   = []
      @value      = nil
    end

    # Create a new child node that stored the string LETTER.  Returns the new node.

    def add_child letter
      new_node = Node.new(letter)
      @children.push new_node
      @children.sort! { |node_a, node_b| node_a.letter <=> node_b.letter }
      new_node
    end
  end

  attr_reader :root

  # Our trie starts with a node with an empty string.

  def initialize
    @root = Node.new
  end

  def [] key
    val = lookup(key)
    val.nil? ? nil : val.unwrap
  end


  def []= key, val
    store(key, Box.new(val))
    return val
  end

  # Return longest common prefix from the trie.

  def prefix node = root, str = ''
    return str + node.letter if node.children.count != 1 or not node.value.nil?
    return prefix node.children[0], str + node.letter
  end

  def keys
    collection = []
    find_keys collection
    collection
  end

  def values
    collection = []
    find_values collection
    collection.map { |box| box.unwrap }
  end

  # Huh.  Must be for debugging or sumthin...

  def dump node = root, indent = ''
    STDERR.puts indent + node.letter + (node.value.nil? ? "" : " " + node.value.inspect) unless node == root
    node.children.each do |n|
      dump n, indent + '→  '
    end
  end

  # TODO: this behavoir seems unexpected... just return matching keys?

  # completion(string) returns [ [ key, val ], [ key, val ] ... ] from
  # the trie object, where string is substring (including an exact
  # match) of all the returned keys. While key is a string, val can be
  # pretty much anything.  The keys are returned sorted.

  def completions string
    completions = []
    completions_helper '', string, root, completions
    return completions
  end

  private

  def completions_helper matched, pending, node, completions
    # two cases:

    # 1) pending is empty, so we've matched the entire string; record
    # the key/value if the current node has a value, then check the
    # children to see if we're a prefix for other nodes.

    if pending.empty? or pending.nil?

      completions.push [ matched, node.value.unwrap ]  if node.value
      node.children.each { |nd| completions_helper(matched + nd.letter, pending, nd, completions) }

    else

    # 2) pending has more letters to consume, so we need to look-ahead
    # at children for a match, recursion will record values.

      nletter, pending = pending[0..0], pending[1..-1]
      matched = matched + nletter

      node.children.each { |nd| completions_helper(matched, pending, nd, completions) if nd.letter == nletter }
    end
  end

  # Store a value for a key. Used for []= above.

  def store key, val, node = root

    head = key[0..0]              # divide and conquer
    tail = key[1..-1]

    found = node.children.select { |n| n.letter == head }.first   # look for our letter in the children..
    found ||=  node.add_child head                                # create a node for it if need be.

    if tail.empty?                # we're done; save value
      found.value = val
    else                          # otherwise, keep dividing, keep conquering.
      store tail, val, found
    end
  end

  # Find all keys. Helper for method keys.

  def find_keys collection, node = root, str = ''
    collection.push str + node.letter unless node.value.nil?
    node.children.each do |nd|
      find_keys collection, nd, str + node.letter
    end
  end

  # Find all values, same order as corresponding keys are
  # returned. Helper for method values.

  def find_values collection, node = root, str = ''
    collection.push node.value unless node.value.nil?
    node.children.each do |nd|
      find_values collection, nd, str + node.letter
    end
  end

  # Lookup value for a key. Used for []

  def lookup key, node = root
    return nil if key.empty?

    head = key[0..0]
    tail = key[1..-1]

    node.children.each do |nd|
      next unless head == nd.letter
      return nd.value if tail.empty? and not nd.value.nil?
      return lookup tail, nd
    end

    return nil
  end

end
