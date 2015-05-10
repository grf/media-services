# -*- coding: utf-8 -*-
#
# TODO: add delete method
# TODO: node should really be equivalent to a trie, so a subtree can use trie methods...
#

# Randy Fischer (rf@ufl.edu) reimplemented this wheel on 2010-06-13.  Pleasant exercise.
#
# Build a trie - my goal was to remove the largest common prefix from
# a list of strings. See the twigs method to get that.  This also does
# the usual trie tricks: stores key/value pairs, orders the keys, etc.
#
# Example program:
#
#  trie = Trie.new
#
#  trie['silos.darchive.fcla.edu:/daitssfs/001'] = :a
#  trie['silos.darchive.fcla.edu:/daitssfs/002'] = :b
#  trie['silos.darchive.fcla.edu:/daitssfs/002'] = :c
#  trie['silos.darchive.fcla.edu:/daitssfs/004'] = :d
#  trie['silos.darchive.fcla.edu:/daitssfs/010'] = :e
#  trie['silos.darchive.fcla.edu:/daitssfs/015'] = :f
#  trie['silos.darchive.fcla.edu:/daitssfs/027'] = :g
#
#  trie['silos.darchive.fcla.edu:/daitssfs/002']     => :c
#
#
#  trie.keys   =>  [ "silos.darchive.fcla.edu:/daitssfs/001", "silos.darchive.fcla.edu:/daitssfs/002", .. ]
#  trie.values =>  [ :a, :c, :d, :e, :f, :g ]
#
#  trie.prefix => 'silos.darchive.fcla.edu:/daitssfs/0'
#
#  trie.twigs  => [ '01', '02', '04', '10', '15', '27' ]

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

  # There's a broken by design bug in here: if the largest common
  # prefix is itself a key, we'll get an empty string. You'll need to
  # check for that case. TODO: fix that.

  def twigs
    len = prefix.length
    keys.map { |k| k[len..-1]}
  end

  # Huh.  Must be for debugging or sumthin...

  def dump node = root, indent = ''
    STDERR.puts indent + node.letter + (node.value.nil? ? "" : " " + node.value.inspect) unless node == root
    node.children.each do |n|
      dump n, indent + '→  '
    end
  end

  private

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

  public

  # returns [ [ key, val ], [ key, val ] ... ]  for all possible completions of match, including exact.

  def completions match
    completions = []
    completions_helper '', match, root, completions
    return completions
  end

  def completions_helper match, tail, node, completions
    # two cases:

    # 1) tail is empty, so we've matched as much as we can; record if node has a value,  then check the children to see if we're a prefix for other nodes.

    if tail.empty? or tail.nil?

      completions.push [ match, node.value.unwrap ]  if node.value
      node.children.each { |nd| completions_helper(match + nd.letter, tail, nd, completions) }

    else

    # 2) tail has more letters to consume, so we need to look-ahead at children for exact matches, recursion will record

      next_letter = tail[0..0]
      match       = match + next_letter
      tail        = tail[1..-1]

      node.children.each { |nd| completions_helper(match, tail, nd, completions) if nd.letter == next_letter }
    end
  end

end
