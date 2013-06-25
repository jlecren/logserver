# vim:fenc=utf-8:et:sw=4:ts=4:sts=4
#
require 'puppet/parameter'
require 'puppet/network/http/api/v1'
require 'puppet/network/http/compression'

Puppet::Type.newtype(:archive) do

    include Puppet::Network::HTTP::API::V1
    include Puppet::Network::HTTP::Compression.module

    @doc = ''

    newproperty(:ensure) do
        Puppet.debug("type archive::newproperty(:ensure)")
        newvalues(:unpacked, :unarchived) do
            provider.unpack
        end
        newvalues(:packed, :archived) do
            provider.pack
        end
    end

    newparam(:name, :isnamevar => true) do
        desc "The URI of the archive."
    end
 
    newparam(:cwd) do
        desc "The directory from which to run the command.  If you supply
        this directory but it does not exist, the command will fail."
        defaultto "/"
    end

    newparam(:source) do
        desc "The file, directory, or list of such which need to be
        (un)archived. If no source is given, it defaults to all files
        under `cwd` for archiving, or all files inside the archive for
        unarchiving."
    end

    newparam(:creates) do
        desc "A file or directory created by unpacking the archive.  If 
        this file exists on disk, the unarchival will not be performed.
        Note: if unpacking is successful but fails to create this file,
        it will be created anyway. This allows consistent behavior with
        other types using the 'creates' parameter (such as exec)."
    end

    newparam(:compression) do
        desc "Compression type to use. Typically this will be derived
        automatically from the archive name."
        defaultto "auto"
        newvalues(
            :auto,
            :compress, :uncompress,
            :gzip, :gz, :z, :gunzip, :ungzip,
            :bzip2,
            :lzip,
            :lzma,
            :lzop,
            :xz,
            /.+/
        )

        # Succumb to madness
        munge do |value|
            Puppet.debug("method munge " + value)
            case value
            when "uncompress"
                "compress"
            when "z", "gz", "gunzip", "ungzip"
                "gzip"
            when "bz2"
                Puppet.debug("method munge praise the lord")
                "bzip2"
            when "auto"
                case self[:name]
                when /\.tgz$/
                    "gzip"
                when /\.tbz2$/
                    "bzip2"
                when /\.txz$/
                    "xz"
                else
                    super
                end
            else
                super
            end
        end
    end

    newparam(:options) do
        desc "Options to pass to the provider."
        defaultto ""
    end

    autorequire(:file) do
        # TODO: add other requirements, such as sources for packing, and the
        # tarball when unpacking
        autos = []
        if val = self[:cwd]
            autos << val
        end
        autos
    end

    private

    # TODO: do something with this
    #
    def get_from_source(source_or_content, &block)
        request = Puppet::Indirector::Request.new(:file_content, :find, source_or_content.full_path.sub(/^\//,''), nil, :environment => resource.catalog.environment)
        request.do_request(:fileserver) do |req|
            connection = Puppet::Network::HttpPool.http_instance(req.server, req.port)
            connection.request_get(indirection2uri(req), add_accept_encoding({"Accept" => "raw"}), &block)
        end
    end

    def chunk_file_from_source(source_or_content)
        get_from_source(source_or_content) do |response|
            case response.code
            when /^2/;  uncompress(response) { |uncompressor| response.read_body { |chunk| yield uncompressor.uncompress(chunk) } }
            else
                # Raise the http error if we didn't get a 'success' of some kind.
                message = "Error #{response.code} on SERVER: #{(response.body||'').empty? ? response.message : uncompress_body(response)}"
            raise Net::HTTPError.new(message, response)
            end
        end
    end
         

end
