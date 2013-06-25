#Type: archive

A puppet type ensuring that archives are packed or unpacked. 

##Examples

        archive { "/var/tmp/mod.tgz":
                ensure => unpacked,
                source => [ "foo", "bar/baz" ]
                cwd    => "/var/tmp/unpack",
        }

The archive at "/var/tmp/mod.tgz" will be unpacked, with only the files or directories "foo" and "bar/baz" extracted. The tar provider is told to change its working directory to "/var/tmp/unpack" to allow relative paths to work.

As no *creates* option is present the mtime of the extracted files will be set to the current system time, allowing comparison later on with the mtime timestamp of the archive. The files will only be extracted again if the archive is modified and has a later timestamp than the files to be extracted.


        file { "/local/test.txz":
                ensure => present
                source => "puppet:///test.txz"
        }
        archive { "/local/test.txz":
                ensure => unpacked,
                compression => "bz2",
                creates => "/etc/.test.txz.unpacked"
        }

The above example downloads a tarball from the server first (because of autorequire on the file), then attempts to extract it. However, this will fail because compression is set to "bz2", whereas the archive is a "xz" archive. Instead, use one of the following:

* compression => "auto"
* compression => "xz"
* or leave out the compression parameter completely, it will default to *auto* which should work fine.

Because we are using *creates => "/etc/.test.txz.unpacked"*, the archive will only be unpacked once. After unpacking "/etc/.test.txz.unpacked" will exist because it was either created by extraction of the archive or because it was "touched" afterwards. Subsequent runs will find the "/etc/.test.txz.unpacked" file and refuse to act.

##Parameters

Please see the automatically created documentation for this type at http://forge.puppetlabs.com/mthibaut/archive.

##Providers

Tar is the only currently supported provider. It supports all compression types tar knows about. You can supply parameters to tar directly by using the *options* parameter.

##Autorequires

* When using "ensure => unpacked", the archive being unpacked will be autorequired.
* TODO: autorequire the source files when using "ensure => packed"

##Limitations:
* For now only local archives are supported. The use of remote archives (loaded over http or via the puppet:// interface) is the next step.
* For now only the tar archive provider exists. It should not be too difficult to write your own provider for e.g. cpio or amanda, if the interface holds up to these cases.
* Autorequire only works when using "ensure => unpacked". Need to also make this work for "ensure => packed", where it would autorequire the files that need to be inside the archive so that they exist before we archive them.

##Authors

Maarten Thibaut (<mthibaut@cisco.com>)

##Copyright

Copyright 2012 Maarten Thibaut. Distributed under the Apache License,
Version 2.0.
