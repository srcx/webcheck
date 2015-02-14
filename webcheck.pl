#!/usr/bin/perl -w

# Web Check 0.2
# (c)2001
# Stepan Roh
# kontroluje webove stranky na platne odkazy

# [10. 2.2001] verze 0.1: prvni verze
# [18. 2.2001] verze 0.2: predelan system kontroly vystupu (-v, -w apod.)

# todo:	nekontroluje odkazy do stranky (#)
#	mohl by tvorit i mapu odkazu
#	kontrolovat i externi odkazy na platnost
#	detekce spatnych velikosti pismen v odkazech (soubor tam je, ale s jinymi velikostmi)
#	moznost sbirat soubory z ruznych adresaru a umistovat je do web stromu
#	mohl by rict i na ktere soubory se vubec neodkazovalo (+ rict vstupni stranky)
#	mohl by kontrolovat i ssi includes
#	kontrolovat soubory postupne (pruchod stromem) a ne tak jak jsou v hashi
#	vystup v xml

$prog_name = 'Web Check';
$prog_major_ver = 0;
$prog_minor_ver = 2;
$prog_copy = '(c)2001 Stepan Roh';
$prog_full_name = "$prog_name $prog_major_ver.$prog_minor_ver $prog_copy";

# konfig. parametry
$user_debug = 0;	# ladici hlasky davaji smysl pouze s --output classic
$user_verbose = 0;
$user_filemask = '(?i)\.s?htm.*$';
$user_npathmask = '';
$user_nprocmask = '';
@builtin_refmasks = (
  '(?i)<\s*a[^>]+href\s*=\s*"(.*?)".*?>',
  '(?i)<\s*img[^>]+src\s*=\s*"(.*?)".*?>',
);
@user_refmasks = ();
$user_prefix = '/';
@user_rewrites = ();
$user_nwebmask = '';
$user_nrefmask = '(?i)^(mailto:|javascript:)';
@builtin_indexfiles = (
  'index.htm', 'index.html', 'index.shtml',
  'index.phtml', 'index.php', 'index.php3',
);
@user_indexfiles = ();
$user_showopts = 0;
$user_output = 'classic';
%user_warnings = ();

if (!@ARGV || ($ARGV[0] eq '--help') || ($ARGV[0] eq '-h') || ($ARGV[0] eq '-?')) {
  print <<END;
$prog_full_name
usage: $0 [options] directory
options:
  -h,  --help                   this help
  -v,  --verbose                verbose mode (output processed file names)
  -vv, --more-verbose           more verbose mode (output all references)
  -f,  --process regexp         regexp for processed files
  -x,  --exclude regexp         regexp for file paths excluded from everything
  -n,  --not-process regexp     regexp for file paths excluded from processing
  -r,  --reference regexp       regexp for references
  -r-, --no-built-in-references disable built-in refmasks
  -p,  --prefix prefix          prefix under which directory is published
  -i,  --indexfile indexfile    directory index file name
  -i-, --no-built-in-indexfiles disable built-in indexfiles
  -m,  --rewrite regexp subst   regexp for rewriting web paths
  -c,  --cont-rewrite re. subst like --rewrite, but do not stop after match
  -e,  --exclude-web-paths re.  regexp for excluded web paths (after rewrite)
  -t,  --exclude-references re. regexp for excluded references
  -o,  --output type		type of output (classic (default) or protocol)
  -w,  --warnings type		output warnings of given type
  -w-, --nowarnings type	do not output warnings of given type
  -s,  --show-options           show options after init and exit
  --                            end of options (optional)

Options --reference, --indexfile, --rewrite, --cont-rewrite, --warnings and
--nowarnings may occur multiple times.
Options --rewrite and --cont-rewrite are evaluated as s/regexp/subst/ (but no
need for escaping any character). They are applied sequentially and rewriting
stops on first matched --rewrite (--cont-rewrite will continue after match).
Web path is full file path where directory is replaced by prefix.

Warning types are:
  all   	all warnings (implicitly --nowarnings all)
  noindex       no index file found
  extref        external reference
  
built-in options:
END
  print "  --process            $user_filemask\n";
  print "  --reference          ".join ("\n".' 'x23, @builtin_refmasks)."\n";
  print "  --prefix             $user_prefix\n";
  print "  --indexfile          ".join ("\n".' 'x23, @builtin_indexfiles)."\n";
  print "  --exclude-references $user_nrefmask\n";
  print "  --output             $user_output\n";
  exit 1;
}
while (@ARGV) {
  $cmd = shift @ARGV;
  if ($cmd eq '-d') {
    $user_debug = 1;
  }
  elsif ($cmd eq '-d-') {
    $user_debug = 0;
  }
  elsif (($cmd eq '-v') || ($cmd eq '--verbose')) {
    $user_verbose = 1;
  }
  elsif (($cmd eq '-vv') || ($cmd eq '--more-verbose')) {
    $user_verbose = 2;
  }
  elsif (($cmd eq '-v-') || ($cmd eq '--noverbose')) {
    $user_verbose = 0;
  }
  elsif (($cmd eq '-f') || ($cmd eq '--process')) {
    $user_filemask = shift @ARGV;
  }
  elsif (($cmd eq '-x') || ($cmd eq '--exclude')) {
    $user_npathmask = shift @ARGV;
  }
  elsif (($cmd eq '-n') || ($cmd eq '--not-process')) {
    $user_nprocmask = shift @ARGV;
  }
  elsif (($cmd eq '-r') || ($cmd eq '--reference')) {
    push (@user_refmasks, shift @ARGV);
  }
  elsif (($cmd eq '-r-') || ($cmd eq '--no-built-in-references')) {
    @builtin_refmasks = ();
  }
  elsif (($cmd eq '-p') || ($cmd eq '--prefix')) {
    $user_prefix = shift @ARGV;
  }
  elsif (($cmd eq '-i') || ($cmd eq '--indexfile')) {
    push (@user_indexfiles, shift @ARGV);
  }
  elsif (($cmd eq '-i-') || ($cmd eq '--no-built-in-indexfiles')) {
    @builtin_indexfiles = ();
  }
  elsif (($cmd eq '-m') || ($cmd eq '--rewrite')) {
    my ($mask, $subst) = (shift @ARGV, shift @ARGV);
    push (@user_rewrites, { 'mask' => $mask, 'subst' => $subst, 'stop' => 1 });
  }
  elsif (($cmd eq '-c') || ($cmd eq '--cont-rewrite')) {
    my ($mask, $subst) = (shift @ARGV, shift @ARGV);
    push (@user_rewrites, { 'mask' => $mask, 'subst' => $subst, 'stop' => 0 });
  }
  elsif (($cmd eq '-e') || ($cmd eq '--exclude-web-paths')) {
    $user_nwebmask = shift @ARGV;
  }
  elsif (($cmd eq '-t') || ($cmd eq '--exclude-references')) {
    $user_nrefmask = shift @ARGV;
  }
  elsif (($cmd eq '-o') || ($cmd eq '--output')) {
    $user_output = shift @ARGV;
  }
  elsif (($cmd eq '-w') || ($cmd eq '--warnings')) {
    my $warn_type = shift @ARGV;
    if ($warn_type eq 'all') {
      $user_warnings{'noindex'} = 1;
      $user_warnings{'extref'} = 1;
    } elsif (($warn_type eq 'noindex') || ($warn_type eq 'extref')) {
      $user_warnings{$warn_type} = 1;
    } else {
      die "Unrecognized warning type $warn_type\n";
    }
  }
  elsif (($cmd eq '-w-') || ($cmd eq '--nowarnings')) {
    my $warn_type = shift @ARGV;
    if ($warn_type eq 'all') {
      %user_warnings = ();
    } elsif (($warn_type eq 'noindex') || ($warn_type eq 'extref')) {
      delete ($user_warnings{$warn_type});
    } else {
      die "Unrecognized warning type $warn_type\n";
    }
  }
  elsif (($cmd eq '-s') || ($cmd eq '--show-options')) {
    $user_showopts = 1;
  }
  elsif ($cmd eq '--') {
    last;
  }
  elsif ($cmd =~ /^-/) {
    die "Unrecognized option $cmd\n";
  }
  else {
    unshift @ARGV, $cmd;
    last;
  }
}

if (!@ARGV) {
  die "No directory specified\n";
}
if (@ARGV > 1) {
  die "Too many arguments\n";
}

$user_dir = shift (@ARGV);

push (@user_refmasks, @builtin_refmasks);
push (@user_indexfiles, @builtin_indexfiles);

$user_warnings = scalar (keys %user_warnings);

if ($user_showopts) {
  print "  --process            $user_filemask\n";
  print "  --exclude            $user_npathmask\n";
  print "  --not-process        $user_nprocmask\n";
  print "  --reference          ".join ("\n".' 'x23, @user_refmasks)."\n";
  print "  --prefix             $user_prefix\n";
  print "  --indexfile          ".join ("\n".' 'x23, @user_indexfiles)."\n";
  print "  --rewrite            ";
  my $first = 1;
  foreach $rule (@user_rewrites) {
    if ($$rule{'stop'}) {
      print ' 'x23 if (!$first);
      print "$$rule{'mask'} $$rule{'subst'}\n";
      $first = 0;
    }
  }
  print "\n" if ($first);
  print "  --cont-rewrite       ";
  $first = 1;
  foreach $rule (@user_rewrites) {
    if (!$$rule{'stop'}) {
      print ' 'x23 if (!$first);
      print "$$rule{'mask'} $$rule{'subst'}\n";
      $first = 0;
    }
  }
  print "\n" if ($first);
  print "  --exclude-web-paths  $user_nwebmask\n";
  print "  --exclude-references $user_nrefmask\n";
  print "  --output             $user_output\n";
  print "  --warnings           ";
  $first = 1;
  foreach $warn_type (keys %user_warnings) {
    print ' 'x23 if (!$first);
    print "$warn_type\n";
    $first = 0;
  }
  print "\n" if ($first);
  exit 0;
}

foreach $rule (@user_rewrites) {
  $$rule{'mask'} =~ s,/,\\/,g;
  $$rule{'subst'} =~ s,/,\\/,g;
}
  
foreach $refmask (@user_refmasks) {
  $refmask =~ s,/,\\/,g;
}
  
# hlavni

# soubory ke zpracovani
@files = ();

# soubory ke zpracovani (mapuje plnou cestu -> web cestu)
%filesmap = ();

# mapa webu (mapuje web cestu -> 1)
%webmap = ( "$user_prefix" => 1 );

# prepisuje web cestu dle @user_rewrites
sub rewrite_webpath ($) {
  my ($path) = @_;
  
  foreach $rule (@user_rewrites) {
    my ($mask, $subst) = ($$rule{'mask'}, $$rule{'subst'});
    my ($expr) = ('$path'." =~ s/$mask/$subst/");
    if (eval $expr) {
      last if ($$rule{'stop'});
    }
  }
  
  return $path;
}

# nacte adresar rekurzivne do @files, %filesmap a %webmap
sub get_files ($$) {
  my ($dir, $web_path) = @_;
  my ($f, @f);
  
  print "Descending into dir $dir\n" if ($user_debug);
  opendir (DIR, $dir) || die "Error opening directory $dir : $!\n";
  @f = sort grep { $_ !~ /^\.\.?$/ } readdir (DIR);
  closedir (DIR) || die "Error closing directory $dir : $!\n";
  
  foreach $f (@f) {
    my ($full_f, $full_web) = ("$dir/$f", "$web_path$f");
    if (($user_npathmask ne '') && ($full_f =~ /$user_npathmask/o)) {
      print "...excluded file $full_f\n" if ($user_debug);
      next;
    }
    if (-d $full_f) {
      $full_web = rewrite_webpath ($full_web) . '/';
      print "... added web path $full_web\n" if ($user_debug);
      $webmap{$full_web} = 1;
      get_files ($full_f, $full_web);
    } else {
      $full_web = rewrite_webpath ($full_web);
      print "... added web path $full_web\n" if ($user_debug);
      $webmap{$full_web} = 1;
      if (($user_nprocmask ne '') && ($full_f =~ /$user_nprocmask/o)) {
        print "... file $full_f excluded from processing\n" if ($user_debug);
        next;
      }
      if ($f =~ /$user_filemask/o) {
        print "... added file $full_f\n" if ($user_debug);
        $filesmap{$full_f} = $full_web;
        push (@files, $full_f);
      } else {
        print "...passed file $full_f\n" if ($user_debug);
      }
    }
  }
  print "Ascending from dir $dir\n" if ($user_debug);
}

get_files ($user_dir, $user_prefix);

# vystup
sub output_start () {
  $out_files_num = $out_errors_sum = $out_warnings_sum = 0;
  $now = time ();
  if ($user_output eq 'classic') {
    print "$prog_full_name\nStarted checking directory $user_dir (web path $user_prefix)...\n" if ($user_verbose);
  } elsif ($user_output eq 'protocol') {
    print "$prog_full_name\nStarted checking directory $user_dir (web path $user_prefix) on ".localtime (time ())."\n\n";
  }
}

sub output_stop () {
  if ($user_output eq 'classic') {
    print "\n$out_files_num files checked in ".(time () - $now)." sec\n" if ($user_verbose);
  } elsif ($user_output eq 'protocol') {
    print "$out_errors_sum errors";
    print ", $out_warnings_sum warnings" if ($user_warnings);
    print " found in $out_files_num files checked in ".(time () - $now)." sec\n\n";
  }
}

sub output_start_file ($$) {
  ($out_file, $out_web) = @_;
  
  if ($user_output eq 'classic') {
    print "Processing file $out_file ($out_web)\n" if ($user_verbose);
  } elsif ($user_output eq 'protocol') {
    # nic
  }
  %out_infos = (); %out_errors = (); %out_warnings = ();
  $out_errors_num = $out_warnings_num = 0;
  $out_files_num++;
}

sub output_stop_file () {
  
  $out_errors_sum += $out_errors_num;
  $out_warnings_sum += $out_warnings_num;
  if ($user_output eq 'classic') {
    # nic
  } elsif ($user_output eq 'protocol') {
    if ($user_verbose || ($out_errors_num + $out_warnings_num > 0)) {
      print "$out_errors_num errors";
      print ", $out_warnings_num warnings" if ($user_warnings);
      print " found in file $out_file (web path $out_web)\n\n";
      foreach $err (keys %out_errors) {
        print "\terror: $err in tags:\n";
        foreach $tag (@{$out_errors{$err}}) {
          print "\t\t$tag\n";
        }
        print "\n";
      }
      foreach $warn (keys %out_warnings) {
        print "\twarning: $warn in tags:\n";
        foreach $tag (@{$out_warnings{$warn}}) {
          print "\t\t$tag\n";
        }
        print "\n";
      }
      foreach $info (keys %out_infos) {
        print "\t$info:\n";
        foreach $msg (@{$out_infos{$info}}) {
          print "\t\t$msg\n";
        }
        print "\n";
      }
    }
  }
}

sub output_reference ($$) {
  my ($ref, $norm_ref) = @_;
  
  if ($user_verbose > 1) {
    if ($user_output eq 'classic') {
      print "...reference to $ref".(defined ($norm_ref) ? " ($norm_ref)" : '')."\n";
    } elsif ($user_output eq 'protocol') {
      push (@{$out_infos{'references'}}, "$ref".(defined ($norm_ref) ? " ($norm_ref)" : ''));
    }
  }
}

sub output_noindexfile ($) {
  my ($tag) = @_;
  
  if (exists $user_warnings{'noindex'}) {
    if ($user_output eq 'classic') {
      print "warning: $out_file: non-existent index file for reference in tag $tag\n";
    } elsif ($user_output eq 'protocol') {
      push (@{$out_warnings{'non-existent index file'}}, $tag);
    }
    $out_warnings_num++;
  }
}

sub output_badref ($) {
  my ($tag) = @_;
  
  if ($user_output eq 'classic') {
    print "error: $out_file: non-existent reference in tag $tag\n";
  } elsif ($user_output eq 'protocol') {
    push (@{$out_errors{'non-existent reference'}}, $tag);
  }
  $out_errors_num++;
}

sub output_extref ($) {
  my ($tag) = @_;
  
  if (exists $user_warnings{'extref'}) {
    if ($user_output eq 'classic') {
      print "warning: $out_file: external reference in tag $tag\n";
    } elsif ($user_output eq 'protocol') {
      push (@{$out_warnings{'external reference'}}, $tag);
    }
    $out_warnings_num++;
  }
}

# zpracovani souboru
sub process_file ($$) {
  my ($file, $web) = @_;
  my ($data);

  output_start_file ($file, $web);
  
  open (F, $file) || (warn ("Error opening file $file : $!\n"), return);
  $data = join ('', <F>);
  close (F) || warn "Error closing file $file : $!\n";
  
  # normalizuje odkaz
  sub normalize_ref ($$) {
    my ($base, $ref) = @_;
    $ref =~ s,#.*$,,;	# odkazy do stranek
    $ref =~ s,\?.*$,,;	# parametry skriptu
    if ($ref =~ m,^\w+://,) {
      return undef;
    }
    if ($ref eq '') {
      return $base;
    }
    my $norm_ref;
    if ($ref =~ m,^/,) {
      $norm_ref = $ref;
    } else {
      $norm_ref = "$base/../$ref";
    }
    # zrusi . a ..
    while ($norm_ref =~ s,(^|/)\.(/|$),,) {};		# .
    while ($norm_ref =~ s,(^|[^/]+)/\.\.(/|$),,) {};	# ..
    $norm_ref =~ s,/+,/,g;				# /////////////
    return $norm_ref;
  }
  
  foreach $refmask (@user_refmasks) {
    $data =~ /^$/;
    while ($data =~ /\G.*?($refmask)/gs) {
      my ($tag, $ref) = ($1, $2);
      if (($user_nrefmask ne '') && ($ref =~ /$user_nrefmask/o)) {
        print "...excluded reference $ref\n" if ($user_debug);
        next;
      }
      my $norm_ref = normalize_ref ($web, $ref);
      if (defined ($norm_ref)) {
        $norm_ref = rewrite_webpath ($norm_ref);
        if (($user_nwebmask ne '') && ($norm_ref =~ /$user_nwebmask/o)) {
          print "...excluded reference $ref ($norm_ref)\n" if ($user_debug);
          next;
        }
      }
      
      print "...detected reference tag $tag\n" if ($user_debug);
      output_reference ($ref, $norm_ref);
      
      if (defined ($norm_ref)) {
        if ($norm_ref =~ /^$user_prefix/o) {
          print "...checking $norm_ref\n" if ($user_debug);
          if (!exists ($webmap{$norm_ref})) {
            print "...  direct hit missed\n" if ($user_debug);
            if (exists ($webmap{"$norm_ref/"})) {
              print "...  directory\n" if ($user_debug);
              my $is_indexfile = 0;
              foreach $indexfile (@user_indexfiles) {
                if (exists ($webmap{"$norm_ref/$indexfile"})) {
                  print "...  index file $indexfile\n" if ($user_debug);
                  $is_indexfile = 1;
                  last;
                }
              }
              if (!$is_indexfile) {
                output_noindexfile ($tag);
              }
            } else {
              output_badref ($tag);
            }
          }
        } else {
          output_extref ($tag);
        }
      } else {
        output_extref ($tag);
      }
    }
  }

  output_stop_file ();
}

output_start ();
foreach $f (@files) {
  process_file ($f, $filesmap{$f});
}
output_stop ();

1;
