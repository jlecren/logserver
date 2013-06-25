define elasticsearch::plugin(
  $ensure = present,
  $url    = undef,
  $file   = undef,
  $source = undef,
  $host   = 'localhost',
  $port   = 9200
  ) {

  require elasticsearch::params

  if ! ($source in [ 'github', 'elasticsearch', 'url', 'file' ]) {
    fail("\"${source}\" is not a valid source parameter value")
  }

  if ( $source == 'file' and $file != 'undef' ) {

    $filenameArray = split($file, '/')
    $basefilename = $filenameArray[-1]

    file { "/tmp/${basefilename}":
      ensure => present,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => $file
    }

    $command = ''

  } else {
    fail('Source set to file but no file provided')
  }

  if ( $source == 'url' and $url != 'undef' ) {
  } else {
    fail('Source set to url, but no url provided')
  }

  if ( $source == 'elasticsearch' ) {
    // check for correct pattern
  } else {
    // fail
  }

  if ( $source == 'github' ) {
    // check for correct pattern
  } else {
    // fail
  }

  exec { "install_plugin_${name}":
    // collect commands
  }


  exec { "check_if_exist_${name}":

  }
}
