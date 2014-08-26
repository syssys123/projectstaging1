require 'mysql2'
require 'cpruntime'
require 'cpruntime/mysql2client'
require 'yaml'

class HomeController < ApplicationController
  include CPRuntime
  def index
    CPRuntime.refreshDedicatedServiceJsonDoc
    p "json-----------#{CPRuntime.service_json_doc}"
    @hosts = getHosts('mysql')
    p @hosts
    config = YAML::load(File.read(Rails.root.to_s + '/config/runtime.yml'))
    p config
    $use_cloudpi_source = config['use_cloudpi_source']
    p $use_cloudpi_source
  end

  # Extracts the connection string for the mysql service from the
  # service information provided by Cloud Foundry in an environment
  # variable.
  def self.mysql_option
    services = JSON.parse(ENV['VCAP_SERVICES'], :symbolize_names => true)
    srv=services.values[0][0][:credentials]
    srv.each {|s|
      if s[:type] =~ /master/
        return {:host => s[:hostname], :port => s[:port], :password => s[:password],:username => s[:username], :database=>s[:name]}
      end
    }
    #    mysql_conf = services.values.map do |srvs|
    #      srvs.map do |srv|
    #        if srv[:label] =~ /^mysql-/
    #        {:host => srv[:credentials][:hostname], :port => srv[:credentials][:port], :password => srv[:credentials][:password]}
    #        end
    #      end
    #    end.flatten!.first
  end

  # Opens a client connection to the mysql service, if one isn't
  # already open.
  def self.mysql(hostname)
    if $use_cloudpi_source
      @mysql = CPRuntime::MySql2Client.new.create_from_svc(hostname)
      begin
        @mysql.query("create table user(name char(20),country char(20));")
      rescue
        puts "Table user is exist."
      end
      return @mysql
    else
      unless @mysql
        client = Mysql2::Client.new(mysql_option)
        #client = Mysql2::Client.new(:host => "ec2-23-20-203-83.compute-1.amazonaws.com",:username => "scalr",:password=>"kPwcIcEgSrNWOPdb9sHD",:database=>"cloudpidb",:port=>3306)
        @mysql = client
        begin
          client.query("create table user(name char(20),country char(20));")
        rescue
          puts "Table user is exist."
        end
      end
      @mysql
    end
  end

  # The action for our set form.
  def set
    m=params[:message].split(":")
    puts m[0],m[1]
    HomeController.mysql(params[:host]).query("insert into user values(" + "\"" + m[0] + "\"" + "," + "\"" + m[1] + "\"" + ");")
    puts "insert into user values(" + "\"" + m[0] + "\"" + "," + "\"" + m[1] + "\"" + ");"
    # Notify the user that we published.
    flash[:store] = true
    redirect_to home_index_path
  end

  def get
    # Synchronously get a message from the mysql
    value = HomeController.mysql(params[:host]).query("select country from user where name = " +  "\"" + params[:message] +  "\"" + ";")
    puts "select country from user where name = " +  "\"" + params[:message] +  "\"" + ";"
    puts "row count",value.count
    msg=""
    value.each do |row|
      msg=row["country"]
    end
    puts "result:",msg
    # Show the user what we got
    #flash[:got] = msg[:payload]
    flash[:got] = msg
    redirect_to home_index_path
  end
end

