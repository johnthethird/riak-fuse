#!/usr/bin/ruby
require 'rubygems'
require 'fusefs'
require 'ripple'
require 'tree'
require 'optparse'
require 'mime/types'

@options = {}
@options[:mount] = "/mnt/riak"
@options[:host] = "localhost"
@options[:port] = 8098
@options[:verbose] = false

opts = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options]\n\nMounts a Riak cluster using the fusefs Ruby driver. \nIf your Riak keys look like /foo/bar/file.txt you can navigate them like you would a filesystem. \nSupports reads only. Requires Ripple gem > 0.6.0\n\n"
  opts.on('-b', '--buckets BUCKETS', Array, "Comma-delimited list of bucket names") {|val| @options[:buckets] = val }
  opts.on('-m', '--mount MOUNT', String, "Mount point for Riak Fuse driver (/mnt/riak)")  {|val| puts val; @options[:mount] = val }  
  opts.on('-H', '--host HOST', String, "Hostname of Riak cluster (localhost)")  {|val| @options[:host] = val}
  opts.on('-p', '--port PORT', Integer, "Port of Riak cluster (8098)")  {|val| @options[:port] = val}
  opts.on('-v', '--verbose')  {@options[:verbose] = true }  
  opts.on_tail("-h", "--help", "-H", "Display this help message.") {puts opts; exit}
end
begin
  opts.parse!(ARGV)
  raise OptionParser::ParseError, "Buckets arg is required." if !@options[:buckets]
rescue OptionParser::ParseError => e
  puts e.message
  puts opts
  exit 1
rescue Exception => e
  exit 1
end

if @options[:verbose]
  def debug(msg); puts msg; end
else
  def debug(msg); end
end

# Given an array of filepaths, put them in a tree structure
class KeyTree
  attr_accessor :all_keys, :tree
  def initialize(all_keys=nil)
    @all_keys = all_keys ? all_keys : []
    @tree = Tree::TreeNode.new("ROOT","Root of tree")
    @all_keys.sort.each do |key|
      root = @tree
      key.split("/").each do |path_part|
        if root[path_part]
          root = root[path_part]
        else
          root = root << Tree::TreeNode.new(path_part,nil)
        end
      end
    end
    debug @tree.printTree
  end

  def is_dir?(path)
    #return !is_file?(path)
    node = tree
    path.split("/").each do |path_part|
      return false unless node = node[path_part]
    end
    node.hasChildren?
  end
  
  def is_file?(path)
    node = tree
    path.split("/").each do |path_part|
      return false unless node = node[path_part]
    end
    true
  end
  
  def list(path)
    return tree.children.map{|n| n.name} if path == "ROOT"
    node = tree
    path.split("/").each do |path_part|
      return false unless node = node[path_part]
    end
    node.hasChildren? ? node.children.map{|n| n.name} : []
  end
end  

# Fuse driver for Riak cluster
class RiakDir < FuseFS::FuseDir
  attr_accessor :client, :initial_buckets, :key_trees
  def initialize(host, port, initial_buckets)
    @client = Riak::Client.new(:host => host, :port => port)
    @initial_buckets = initial_buckets
    @key_trees = {}
  end
  
  #  Read the contents of a path
  def contents(path)
    debug "Contents: #{path}"
    return initial_buckets if path == "/" 
    bucket, key = parse_path(path)
    if bucket && !key
      get_tree(bucket).list("ROOT")
    elsif bucket && key
      get_tree(bucket).list(key)
    else
      []
    end
  end

  def directory?(path)
    debug "Directory?: #{path}"
    return true if path == "/"
    bucket, key = parse_path(path)
    bucket && !key ? true : get_tree(bucket).is_dir?(key)
  end

  def file?(path)
    debug "File?: #{path}"
    return false if path == "/"
    bucket, key = parse_path(path)
    bucket && key ? get_tree(bucket).is_file?(key) : false
  end

  def read_file(path)
    debug "ReadFile: #{path}"
    bucket, key = parse_path(path)
    begin
      robj = client[bucket].get(key)
      puts robj.data
      robj.serialize(robj.data)
    rescue Exception => e
      puts "Error reading file: #{e.message}" 
    end
  end

# TODO implement writing to Riak. What are the semantics? How do directories work? etc
=begin  
  def can_delete?(path); debug "CanDelete? #{path}"; file?(path); end
  def delete(path)
    debug "Delete: #{path}"
    bucket, key = parse_path(path)
    robj = client[bucket].get(key)
    robj.delete
    flush_cache(bucket)
  end
  
  def can_write?(path); debug "CanWrite? #{path}"; true; end
  def write_to(path, data)
    debug "WriteTo: #{path}"
    begin
      path.match(%r{/([^/]+)$}); filename = $1
      bucket, key = parse_path(path)
      robj = client[bucket].get_or_new(key)
      robj.content_type = MIME::Types.type_for(filename).to_s
      robj.data = data
      flush_cache(bucket)
    rescue Exception => e
      puts e.to_yaml
    end
  end
  
  def can_mkdir?(path); true; end
  def mkdir(path)
    debug "MakeDir: #{path}"
    bucket, key = parse_path(path)
    robj = client[bucket].get_or_new(key)
    if !robj.vclock
      robj.content_type = "text/plain"
      robj.data = "riak-fuse directory placeholder"
      robj.store
      flush_cache(bucket)
    end
    true
  end    
  
  def can_rmdir?(path); debug "CanRmdir? #{path}"; true; end
  def rmdir(path); debug "Rmdir: #{path}"; true; end
=end
  private
  # Cache the trees generated for each bucket, as its expensive
  def get_tree(bucket)
    key_trees[bucket] ||= KeyTree.new(client[bucket].keys)
  end    
  
  def flush_cache(bucket)
    key_trees[bucket] = nil
  end

  # Maybe use this to find subsets of keys? TODO
  def matching_keys(regex)
    results = Riak::MapReduce.new(client).add(bucket).map("function(value,keyData,arg) {
                     var re = new RegExp(arg);
                     return value.key.match(re) ? [value.key] : [];
                   }", :keep => true, :arg => regex).run
  end

  # [bucket, key]
  def parse_path(path)
    path.match(%r{/([^/]+)(.*)})
    bucket, key = $1, $2
    bucket = (bucket && bucket.length == 0) ? nil : bucket
    key = (key && key.length == 0) ? nil : key
    key.gsub!(%r{^/},"") if key
    [bucket, key]
  end    
end

#
#  Make sure we have a mount-point
#
if ( ! File.directory?( @options[:mount] ) )
  puts "Mount point #{@options[:mount]} doesn't exist, create it with mkdir #{@options[:mount]}"
  exit 1
end

#
#  Make sure we're root
#
if ( ENV["USER"] != "root" )
  puts "Must be run as root."
  exit 1
end

#
#  Load the module - which might not be present.
#
Kernel.system( "modprobe fuse    2>/dev/null >/dev/null" )

# Unmount when ^C is pressed
trap("INT") do
  puts "Unmounting #{@options[:mount]}"
  `fusermount -u #{@options[:mount]}`
  exit 1
end 

puts "Mounting #{@options[:mount]} to Riak cluster at http://#{@options[:host]}:#{@options[:port]}/riak"
puts "Verbose=TRUE" if @options[:verbose]
puts "Press ^C to quit..."
dir = RiakDir.new(@options[:host], @options[:port], @options[:buckets])
FuseFS.set_root(dir)
FuseFS.mount_to @options[:mount], "allow_other"
FuseFS.run

