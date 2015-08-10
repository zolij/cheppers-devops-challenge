require 'rubygems'
require 'aws-sdk'
require 'ipaddress'
require 'yaml'
require 'net/ssh'

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
    start = @@ec2.run_instances({
                                    image_id: @@image_id,
                                    min_count: 1,
                                    max_count: 1,
                                    instance_type: 't2.micro',
                                    key_name: 'sajat',
                                    security_group_ids: ['cheppers'],
                                })

    instances = start.instances

    instance_id = instances[0].instance_id
  end

  # terminate an instance
  def terminate_instance(instance_id)
    terminate = @@ec2.terminate_instances({
                                              instance_ids: [instance_id]
                                          })
    return terminate
  end

  def get_instance_ids(running_only = false)
    ids = Hash.new
    filter_hash = Hash.new
    filter_hash = {name:  'instance-state-name', values: ['running']} if running_only
    desc = @@ec2.describe_instances({
                                        filters: [ filter_hash ]
                                    })

    desc.reservations.each do |reservation|
      reservation.instances.each do |instance|
        ids[instance.instance_id] = instance.state.name
      end
    end
    return ids
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

  def install_application(instance_id, package_name)
    @ipaddr = $aws.fetch_public_ip(instance_id)
    @ssh = Net::SSH.start(@ipaddr, 'ubuntu', :host_key => "ssh_rsa", :encryption => "blowfish-cbc", :keys => [ "#{Dir.home}/Dropbox/id_rsa" ], :compression => "zlib")
    if @ssh.exec!("dpkg -l #{package_name} &> /dev/null;echo $?").to_i > 0
      @res = @ssh.exec!("sudo apt-get update && sudo apt-get install #{package_name} -y")
      if @ssh.exec!("dpkg -l #{package_name} &> /dev/null;echo $?").to_i > 0
        return false
      end
    end
    @ssh.close
    return true
  end
end

# menu methods
def create_new_instance
  print "Start new instance... "
  instance_id = $aws.create_instance
  puts "done (instance id: #{instance_id})"
  return instance_id
end

def get_public_ip(instance_id = nil)
  if instance_id.nil?
    @ids = $aws.get_instance_ids(true)
    if @ids.nil? || @ids.size == 0
      puts "No running instances"
      return false
    end
    if @ids.size == 1
      instance_id = @ids.keys[0]
    end
  end

  print "Waiting for public ip"
  @ip_address = $aws.fetch_public_ip(instance_id) { print "." }
  puts " Found: #{@ip_address}"
end

def terminate_instance(instance_id = nil)
  if instance_id.nil?
    @ids = $aws.get_instance_ids(true)
    if @ids.nil? || @ids.size == 0
      puts "No running instances"
      return false
    end
    if @ids.size == 1
      instance_id = @ids.keys[0]
    end
    if @ids.size > 1
      puts "Multiple instances found, please choose one of them. Type \"all\" to terminate all."
      counter = 1
      @ids.each_key { |id|
        puts "#{counter}. #{id}"
        counter+=1
      }
      print "Your choice: "
      choice = gets.chomp
      if(choice == "all")
        @ids.each_key { |id| terminate_instance(id)}
        return true
      else
        if choice.to_i > 0 && choice.to_i < counter
          instance_id = @ids.keys[choice.to_i-1]
        else
          puts "You have to select from the list, exiting..."
          return false
        end
      end
    end
  end

  puts "Instance terminated (id: #{instance_id})"
  return $aws.terminate_instance(instance_id)
end

def install_package(package)
  @ret = $aws.install_application('i-5909c2f2', package)
  if(!@ret)
    puts "Package installation (#{package}) was unsuccessful"
  else
    puts "Package #{package} installed successful"
  end
end


# main program

$aws = Aws_Manage.new

puts "Choose an option"
puts "1. create new instance"
puts "2. get instances public ip"
puts "3. terminate an instance"
puts "4. install puppet"
print "Your choice (number): "
choice = gets.chomp

case choice.to_i
  when 1
    create_new_instance
  when 2
    get_public_ip
  when 3
    terminate_instance
  when 4
    install_package('puppet')
  else
    puts "Please choose a number from the list"
end