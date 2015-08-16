exec { "puppet module install puppetlabs-mysql":
  path    => "/usr/bin:/usr/sbin:/bin",
  onlyif  => "test `puppet module list | grep puppetlabs-mysql | wc -l` -eq 0"
}
