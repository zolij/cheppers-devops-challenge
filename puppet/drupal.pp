# install drush package
package { 'drush':
  ensure => installed,
}

mysql::db { 'drupal':
  user     => 'drupal',
  password => $::drupalsqlpw,
  host     => 'localhost',
  grant    => ['ALL'],
}
