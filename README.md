FUSE Driver for Riak
====================

_*WARNING!!! This is a toy. Do not point it at a cluster you care about. You have been warned.*_

This proof-of-concept will mount your Riak cluster to your *nix filesystem, and allow you to browse the keyspace using standard tools like ls, cd, cat, etc...

Prerequisites
-------------
  * FUSE drivers for your OS
  * sudo gem install rubytree ripple

Installation
------------

    git clone http://github.com/johnthethird/riak-fuse.git
    cd riak-fuse
    sudo ./riak-fuse.rb -b bucket1,bucket2
    (Then, in another terminal...)
    cd /tmp/riak
    ls
  
Notes
-----
  * You must specify your bucket names with the -b option. See -h for other options.
  * Only reading of keys has been implemented, not writing. 
  * If your keys look like /foo/bar/logo.png then you will be able to navigate them like you would a directory structure. If your keys dont look like that, then they will show up all in the root directory.
  * This script will ask Riak to list all keys, so beware if your buckets have too many keys.
  
JSAWK
-----
If your keys contain JSON data, check out [JSAWK](http://github.com/micha/jsawk) for a really cool way to manipulate it from the command line. For example, if you had it and riak-fuse installed, you could do things like:

    cat /mnt/riak/users/* | jsawk 'if (this.city != "Paris") return null'
  
This code would output the records of users that live in Paris. This is just scratching the surface of what jsawk can do.


License
-------
(The MIT License)

Copyright (c) 2010 John Lynch and Rigel Group, LLC

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.