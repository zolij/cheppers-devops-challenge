require 'aws-sdk'

class Aws_Manage
  @@image_id = 'ami-d05e75b8'

  def initialize

    # windows openssl hack
    Aws.use_bundled_cert!

    # aws region setting
    Aws.config[:region] = 'us-east-1'

    # ec2 client initialization (class scope)
    @@ec2 = Aws::EC2::Client.new()

  end

  def start_instance
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
end

aws = Aws_Manage.new

puts aws.start_instance