#!/usr/bin/perl
# rfc1867.pl <main/rfc1867.c>: apply the PHP2Shell part of upstream rfc1867.c (identical to the
# PHP-8.0 backport) to the vendor 7.4.33-6 file, whose context already has the (unsigned char)
# ctype casts and the max_multipart_body_parts limit. Each change must match exactly once.
use strict; use warnings;
my $f = shift; local $/; open my $in, "<", $f or die; my $s = <$in>; close $in;
sub once { my ($from, $to, $what) = @_; my $n = () = $s =~ /\Q$from\E/g; die "$what: found $n times\n" unless $n == 1; $s =~ s/\Q$from\E/$to/; }
once("/* parse headers */\n",
"static zend_bool php_mime_should_save_hdr(const char *name)\n{\n\treturn !strcasecmp(name, \"Content-Disposition\")\n\t\t|| !strcasecmp(name, \"Content-Type\");\n}\n\nstatic char *php_mime_get_hdr_value(zend_llist header, char *key);\n\n/* parse headers */\n", "hdr helper");
once("\t\t\t*value = \x27\\0\x27;\n\t\t\tdo { value++; } while (isspace((unsigned char)*value));\n\n\t\t\tkey = estrdup(line);\n\t\t\tsmart_string_appends(&buf_value, value);\n",
"\t\t\t*value = \x27\\0\x27;\n\n\t\t\t/* Keep only headers we use, and ignore duplicates */\n\t\t\tif (!php_mime_should_save_hdr(line)\n\t\t\t\t\t|| php_mime_get_hdr_value(*header, line)) {\n\t\t\t\tkey = NULL;\n\t\t\t} else {\n\t\t\t\tkey = estrdup(line);\n\t\t\t\tdo { value++; } while (isspace((unsigned char)*value));\n\t\t\t\tsmart_string_appends(&buf_value, value);\n\t\t\t}\n", "header filter");
once("static char *substring_conf(char *start, int len, char quote)\n{\n\tchar *result = emalloc(len + 1);\n\tchar *resp = result;\n\tint i;\n",
"static char *substring_conf(char *start, size_t len, char quote)\n{\n\tchar *result = emalloc(len + 1);\n\tchar *resp = result;\n\tsize_t i;\n", "substring_conf size_t");
once("return substring_conf(str, (int)strlen(str), quote);", "return substring_conf(str, strlen(str), quote);", "quoted call");
once("return substring_conf(str, strend - str, 0);", "return substring_conf(str, (size_t)(strend - str), 0);", "unquoted call");
open my $out, ">", $f or die; print $out $s; close $out; print "rfc1867.c rebased\n";
