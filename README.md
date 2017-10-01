# Web Check

**Warning: unmaintained since 2001!**

Web Check is a program for off-line web consistency testing.

## Usage
```
./webcheck.pl [options] directory

options:
  -h,  --help                   this help
  -v,  --verbose                verbose mode (output processed file names)
  -vv, --more-verbose           more verbose mode (output all references)
  -f,  --process regexp         regexp for processed files
  -x,  --exclude regexp         regexp for file paths excluded from
                                everything
  -n,  --not-process regexp     regexp for file paths excluded from
                                processing
  -r,  --reference regexp       regexp for references
  -r-, --no-built-in-references disable built-in refmasks
  -p,  --prefix prefix          prefix under which directory is published
  -i,  --indexfile indexfile    directory index file name
  -i-, --no-built-in-indexfiles disable built-in indexfiles
  -m,  --rewrite regexp subst   regexp for rewriting web paths
  -c,  --cont-rewrite re. subst like --rewrite, but do not stop after match
  -e,  --exclude-web-paths re.  regexp for excluded web paths (after
                                rewrite)
  -t,  --exclude-references re. regexp for excluded references
  -o,  --output type            type of output (classic (default) or
                                protocol)
  -w,  --warnings type          output warnings of given type
  -w-, --nowarnings type        do not output warnings of given type
  -s,  --show-options           show options after init and exit
  --                            end of options (optional)
```
Options --reference, --indexfile, --rewrite, --cont-rewrite, --warnings and
--nowarnings may occur multiple times.
Options --rewrite and --cont-rewrite are evaluated as s/regexp/subst/ (but
no need for escaping any character). They are applied sequentially and
rewriting stops on first matched --rewrite (--cont-rewrite will continue
after match).
Web path is full file path where directory is replaced by prefix.
```
Warning types are:
  all           all warnings (implicitly --nowarnings all)
  noindex       no index file found
  extref        external reference
```
```
built-in options:
  --process            (?i)\.s?htm.*$
  --reference          (?i)<\s*a[^>]+href\s*=\s*"(.*?)".*?>
                       (?i)<\s*img[^>]+src\s*=\s*"(.*?)".*?>
  --prefix             /
  --indexfile          index.htm
                       index.html
                       index.shtml
                       index.phtml
                       index.php
                       index.php3
  --exclude-references (?i)^(mailto:|javascript:)
  --output             classic
```
## Example
```
./webcheck.pl --output protocol -v- -w all -w- extref --cont-rewrite
'(\.html?)\.([^./]*)$' '$1' --prefix '/~user/' --rewrite 'ezine/share'
'ezine' --not-process 'textual/' --exclude 'software/(srcs|docs)'
--exclude-references
~/'((?i)^(mailto:|javascript:))|(software/(srcs|docs))|((docs|srcs)/software)'
~/WWW

  --output protocol	format output as nice protocol
  -v-			not verbose
  -w all		all warnings
  -w- extref		ignore external references
  --cont-rewrite '(\.html?)\.([^./]*)$' '$1'
			rewrite all paths ending in .html.* to .html (e.g.
			language versions like .html.it)
  --prefix '/~user/'	web prefix of given directory (~/WWW/x.html ->
			/~user/x.html)
  --rewrite 'enzine/share' 'ezine'
			rewrite all paths with ezine/share as ezine (e.g.
			/~user/ezine/share/x.html -> /~user/ezine/x.html -
			useful for server side includes)
  --not-process 'textual/'
			do not process files from textual/ directory, but
			count references leading into this directory
  --exclude 'software/(srcs|docs)'
			exclude files from software/srcs and software/docs
			directories - references into these directories will
			be treated as missing (useful for big directories
			with generated files, because it speeds up
			processing)
  --exclude-references ~/'((?i)^(mailto:|javascript:))|(software/(srcs|docs))|((docs|srcs)/software)'
			exclude references with mailto and javascript
			protocols and references into excluded directories
  ~/WWW			directory to process
```
