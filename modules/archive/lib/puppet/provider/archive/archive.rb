# vim:fenc=utf-8:et:sw=4:ts=4:sts=4
require 'pathname'
require 'puppet/provider'

## The base class for Archive providers.
#class Puppet::Provider::Archive < Puppet::Provider
#

Puppet::Type.type(:archive).provide :tar do
    desc "Support via `archive`."

    commands :tar => "tar", :curl => "curl"

    def unpack
        args = []
        # If we are not using :creates, we have no way to determine
        # if the archive needs to be unpacked at a later time. So we
        # set the mtime in that case.
        creates = @resource[:creates]
        args << "-m" unless creates and creates.length
        # Directory to change to before running
        args << "-C" <<  @resource[:cwd]
        # Determine compression
        args << _compression_flag
        # Extract
        args << "-x"
        # Filename is the last option
        args << "-f" << @resource[:name]
        # Now list the sources to unarchive
        args << @resource[:source] if @resource[:source].length
        Puppet.debug("method archive::tar::unpack: tar " << args.join(" "))
        tar args
        if creates and creates.length and not File.exists?(creates)
            # Touch the new file
            File.new(creates,"w").write(" ")
        end
    end

    def pack
        args = []
        # Directory to change to before running
        args << "-C" << @resource[:cwd]
        # Determine compression
        args << _compression_flag
        # Create
        args << "-c"
        # Filename is the last option
        args << "-f" << @resource[:name]
        # Now list the sources to archive
        args << @resource[:source] if @resource[:source].length
        Puppet.debug("method archive::tar::pack: tar " << args.join(" "))
        tar args
    end

    # Traverse a file system structure and run a lambda on each file
    # Returns true the first time the lambda returns true
    def traverse(lamb, files)
        Puppet.debug("method traverse into " + files.join(" "))
        files = [files] unless files.is_a?(Array)
        files.detect do |file|
            # Stop if our lambda returns true
            lamb.call(file) ||
            if File.directory?(file)
                Dir.entries(file).reject{|i| i == '..' || i == '.'}.detect do |d|
                    # Stop if any of our children returns true
                    traverse(lamb, Pathname.new(file) + d)
                end
            end
        end
    end

    def ensure
        arch_mtime = _uri_mtime(@resource[:name])
        case @resource[:ensure]
        when :packed, :archived
            newer = lambda { |x|
                Puppet.debug("method lambda: file " + x + " mtime " + File.mtime(x).to_s)
                File.mtime(x) > arch_mtime
            }
            files = _absolute_dir(@resource[:source] || ".")
            if traverse(newer, files)
                # A newer file has been found, so it is in the :unpacked
                # state. This will cause it to be (re)archived
                :unpacked
            else
                :packed
            end
        when :unpacked, :archived
            # The only meaningful semantics for ensuring that a tar archive
            # is unpacked, are:
            #   1) We determine if the archive contains any newer files.
            #      If so, extract the archive. For this we need GNU tar's
            #      --full-time option, which was introduced in tar 1.24.
            #      Sadly, this version isn't available on most
            #      distributions.
            #
            #   2) Use the date/time on the archive instead. If it is
            #      newer than any of the files already unpacked, (or the
            #      unpacked file doesn't exist) then unpack. To avoid
            #      repeated unpacks, use the :creates parameter when
            #      unpacking.
            #
            # TODO:
            #   1) Add version check for tar v1.24 and use first semantics
            #      if available.
            #   2) Add code to handle --full-time
            #   2) Make :creates optional for v1.24 and higher
            creates = @resource[:creates]
            if creates and creates.length and not File.exists?(creates)
                # If :creates is specified, then force unpacking if the
                # file it points to isn't there yet.
                return :packed
            end
            # Else we compare the datetimes
            newer = lambda { |x|
                Puppet.debug("method lambda: archive mtime " + arch_mtime.to_s + " file " + x + " mtime " + File.mtime(x).to_s)
                arch_mtime > File.mtime(x)
            }
            files = _absolute_dir(@resource[:source] || ".")
            if traverse(newer, files)
                # The archive is newer, so it is in the :packed state.
                # This will cause it to be unarchived.
                :packed
            else
                :unpacked
            end
        end
    end

    def ensure=(value)
        Puppet.debug("method archive::tar::ensure=(#{value})")
        case value
        when :unpacked, :unarchived
            unpack
        when :packed, :archived
            pack
        else
            fail("Unknown ensure value", value)
        end
        false
    end

    # Local functions, not to be used by parents or other classes
    def _uri_mtime(file)
        # For now, only accepts abcolute filenames accepted by File
        # TODO: allow http
        begin
            File.mtime(file)
        rescue
            # Return a Unix time of 0 if no file found
            Time.gm(1970,"jan",1,0,0,0)
        end
    end

    def _absolute_dir(dirs)
        Puppet.debug("method absolute_dir " + dirs.join(" "))
        dirs = [dirs] unless dirs.is_a?(Array)
        prefix = Pathname.new(@resource[:cwd])
        dirs.collect do |dir|
            p = Pathname.new(dir)
            if p.absolute?
                p
            else
                prefix + p
            end
        end
    end

    def _compression_flag
        #flag = @resource[:compression].to_s
        #Puppet.debug("method _compression_flag value ??" + self['compression'].to_s)
        Puppet.debug("method _compression_flag value " + resource[:compression].to_s)
        case @resource[:compression]
        when "gzip"
            "-z"
        when "bzip2"
            "-j"
        when "compress"
            "-Z"
        when "xz"
            "-J"
        when "lzip"
            "--lzip"
        when "lzma"
            "--lzma"
        when "lzop"
            "--lzop"
        when "auto"
            "-a"
        else
            "-a"
        end
    end

end
