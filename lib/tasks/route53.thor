require 'rubygems'
require 'fog'
require 'fog/dns/parsers/aws/list_resource_record_sets'
require 'digest/sha1'

class Route53 < Thor

  desc 'zones', 'Lists all the zone registered with this account'
  def zones
    zones = dns_manager.zones
    if zones.empty?
      say "No zones defined", :red
    else
      zones.each do |zone|
        show_zone_header(zone)
      end
    end
  end

  desc 'create_zone DOMAIN_NAME', 'Create a new zone'
  method_option :description, :aliases => '-d', :desc => 'Description of the zone'
  def create_zone(domain_name)
    zone = dns_manager.zones.create(
      :domain => domain_name,
      :description => options[:description]
    )
    say 'Added zone', :green
    show_zone_header(zone)
  end

  desc 'destroy_zone ZONE_ID', 'Deletes an existing zone'
  method_options :yes => false
  def destroy_zone(zone_id)
    zone = find_zone_by_id(zone_id)
    say "Destroying zone #{zone.id}", :red
    return unless options[:yes] || yes?("Are you sure?")
    zone.destroy
  end

  desc 'show_zone ZONE_ID', 'Shows the contents of a zone'
  def show_zone(zone_id)
    zone = find_zone_by_id(zone_id)
    show_zone_header(zone)
    if zone.nameservers.nil?
      show_key_value 'nameserver', 'none'
      say "nameserver: none"
    else
      zone.nameservers.each do |ns|
        show_key_value 'nameserver', ns
      end
    end
  end

  desc  'records ZONE_ID [TYPE]', 'Lists the records of a zone'
  def records(zone_id, type = nil)
    zone = find_zone_by_id(zone_id)
    type = check_record_type(type) if type
    show_zone_header(zone)
    records = zone.records.select { |record| type.nil? || type == record.type }
    if records.empty?
      say 'No records defined', :red
    else
      records.each { |record| show_record(record) }
    end
  end

  desc 'create_record ZONE_ID', 'Creates a new record in the specified zone'
  method_option :type, :aliases => '-t', :required => true, :desc => 'Type of the record'
  method_option :name, :aliases => '-n', :required => true, :desc => 'Name of the record'
  method_option :value, :aliases => '-v', :required => true, :type => :array, :desc => 'Value/IP for the record'
  method_option :ttl, :default => 30, :desc => 'TTL of the record in minutes'
  def create_record(zone_id)
    zone = find_zone_by_id(zone_id)
    record_attributes = {
      :type => check_record_type(options[:type]),
      :name => options[:name],
      :ip => options[:value],
      :ttl => options[:ttl] * 60,
    }
    say "Attributes: #{record_attributes.inspect}", :red
    record = zone.records.create(record_attributes)
    show_record(record)
  end

  desc 'destroy_record ZONE_ID RECORD_NAME', 'Destroy the DNS entry associated with the record'
  method_options :yes => false
  def destroy_record(zone_id, record_hash)
    record = find_record_in_zone(zone_id, record_hash)
    say "Destroying record #{record.name}", :red
    show_record(record)
    return unless options[:yes] || yes?('Are you sure?')
#    record.ip = [ '"v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCPVsc1ozsu3l5qeeX7OHl9OdtjOIQQpbsm7wurpTPoZKBqI5M1CcLzft8P71A/oBjQytZ6OD/80zfQYL/2dyp+1QnmnR/pb3b3A9YlRgGsUJwK7TMBW8Wh6gUqxOkMewnDZITrTeV7BW6z68gL9/29soW72+x59/8qdGvAo+S5xwIDAQAB"' ]
    record.destroy
  end

#   desc 'update_record ZONE_ID RECORD_NAME', 'Updates a record'
#   method_option :type, :aliases => '-t', :desc => 'Type of the record'
#   method_option :append_value, :aliases => '-a', :type => :array, :desc => 'Append Value/IP for the record'
#   method_option :value, :aliases => '-v', :type => :array, :desc => 'Value/IP for the record'
#   method_option :ttl, :default => 30, :desc => 'TTL of the record in minutes'
#   def update_record(zone_id, record_name)
#     record = find_record_in_zone(zone_id, record_name)
#     record.type = check_record_type(options[:type]) if options[:type]
#     record.ip = record.ip.push(options[:append_value]).flatten.uniq.compact
#
#     say "ip: #{record.ip}", :red
#     zone = record.zone
#     record.destroy
#
#     zone.records.create(
#     record.zone.records
#
#     find_zone_by_id(zone_id).records.create
#     record.
#   end

private

  def show_zone_header(zone)
    show_title("Zone information")
    show_key_value 'zone id', zone.id
    show_key_value 'domain', zone.domain
    show_key_value 'description', zone.description || '(no description)'
  end

  def show_record(record)
    show_title("Record information")
    #show_key_value 'site id', record.id || '(not set)'
    show_key_value 'id', record_hash(record)
    show_key_value 'name', record.name
    show_key_value 'type', record.type
    show_key_value 'ip', record.ip
    show_key_value 'ttl', record.ttl
  end

  def show_title(title, color=:blue)
    say(title,color)
  end

  def show_key_value(key, value, color= nil)
    say("#{key.rjust(20)}: #{value}", color)
  end

  def check_record_type(type)
    record_type = type.to_s.upcase
    return record_type if %w(A  AAAA  CNAME  MX  NS  PTR  SOA  SPF  SRV  TXT).include?(record_type)
    raise MalformattedArgumentError, "Invalid record type #{type}"
  end

  def record_hash(record)
    return Digest::SHA1.new.update([record.zone.id, record.name, record.type].map(&:to_s).join('-')).hexdigest
  end

  def find_record_in_zone(zone_id, record_id)
    zone = find_zone_by_id(zone_id)
    zone.records.each do |record|
      return record if record_hash(record) == record_id
    end
    say "Record #{record_id} not found in zone #{zone_id}", :red
    exit 1
  end

  def find_zone_by_id(zone_id)
    zone = dns_manager.zones.get(zone_id)
    if zone.nil?
      say "Zone #{zone_id} not found", :red
      exit 1
    end
    return zone
  end

  def dns_manager
    return @dns_manager if defined?(@dns_manager)
    c = config
    @dns_manager = Fog::DNS.new(
      :provider => 'AWS',
      :aws_access_key_id => c['aws_access_key_id'],
      :aws_secret_access_key => c['aws_secret_access_key']
    )
    return @dns_manager
  end

  def config
    YAML.load_file File.expand_path('../../../config/aws.yml', __FILE__)
  end

end

#
#
