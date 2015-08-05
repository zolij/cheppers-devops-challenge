require 'aws-sdk'
require 'ipaddress'
require 'yaml'

class Aws_Manage
  @@image_id = 'ami-d05e75b8'

  def initialize

    # windows openssl hack
    Aws.use_bundled_cert!

    # load config
    @config = YAML.load_file 'config.yaml'

    # set region
    Aws.config[:region] = @config['region']

    # set login credentials
    Aws.config[:credentials] = Aws::Credentials.new(@config['access_key_id'], @config['secret_access_key'])

    # ec2 client initialization (class scope)
    @@ec2 = Aws::EC2::Client.new

  end

  # start new instance
  def create_instance
    start = @@ec2.run_instances(
        image_id: @@image_id,
        min_count: 1,
        max_count: 1,
        instance_type: 't2.micro',
        key_name: 'sajat',
        security_group_ids: ['cheppers'],
    )

    instances = start.instances

    instance_id = instances[0].instance_id
  end

  # fetch public ip for specific instance
  def fetch_public_ip(instance_id)
    while true do
      desc = @@ec2.describe_instances({
                                         instance_ids: [instance_id]
                                     })
      ipaddr = desc.reservations[0].instances[0].public_ip_address
      if (IPAddress.valid? ipaddr)
        return ipaddr
      end
      sleep 5
      yield
    end
  end
end


aws = Aws_Manage.new
begin
instance_id = aws.create_instance

print "Waiting for public ip"

ip_address = aws.fetch_public_ip(instance_id) { print "." }

puts " Found: #{ip_address}"
end