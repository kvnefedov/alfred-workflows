#!/usr/bin/ruby

require 'fileutils'
require 'net/http'
require Dir.getwd + '/_licensed/terminal-notifier/lib/terminal-notifier.rb'

Local_templates = ENV['alfred_workflow_data'] + '/local/'
Remote_templates = ENV['alfred_workflow_data'] + '/remote'
FileUtils.mkdir_p(Local_templates) unless Dir.exist?(Local_templates)
FileUtils.touch(Remote_templates) unless File.exist?(Remote_templates)

def finder_dir
  %x{osascript -e 'tell application "System Events"
     set front_app to name of first process whose frontmost is true
     if front_app is "Finder" then
     tell application "Finder" to return (POSIX path of (folder of the front window as alias))
     else if front_app is "Path Finder" then
     tell application "Path Finder" to return (POSIX path of (target of front finder window))
     else
     return (POSIX path of (path to home folder))
     end if
     end tell'}.sub(/\n$/, '/')
end

def notification(message)
  TerminalNotifier.notify(message, title: 'TemplatesManager')
end

def local_list
  Dir.entries(Local_templates).reject { |entry| entry =~ /^(\.{1,2}$|.DS_Store$)/ }
end

def remote_list
  File.readlines(Remote_templates)
end

def local_edit
  system('open', Local_templates)
end

def remote_edit
  system('open', '-t', Remote_templates)
end

def local_add(path)
  path_basename = File.basename(path)

  if local_list.include?(path_basename)
    notification('You already have a template with that name')
    abort 'A template with that name already exists'
  else
    FileUtils.cp_r(path, Local_templates)
    notification('Added to local templates')
  end
end

def remote_add(url)
  if remote_list.include?(url)
    notification('You already have a template with that name')
    abort 'A template with that name already exists'
  else
    File.open(Remote_templates, 'a') do |link|
      link.puts url
    end
    notification('Added to remote templates')
  end
end

def local_delete(local_array_pos)
  system(Dir.getwd + '/_licensed/trash/trash', '-a', Local_templates + local_list[local_array_pos])
end

def remote_delete(remote_array_pos)
  tmp_array = remote_list
  tmp_array.delete_at(remote_array_pos)

  File.open(Remote_templates, 'w+') do |line|
    line.puts tmp_array
  end
end

def local_info
  puts "<?xml version='1.0'?><items>"

  if local_list.empty?
    puts "<item uuid='none' arg='none' valid='no'>"
    puts '<title>List templates (tml)</title>'
    puts '<subtitle>You need to add some local templates, first</subtitle>'
    puts '<icon>icon.png</icon>'
    puts '</item>'
  else
    local_list.each_index do |local_array_pos|
      template_title = local_list[local_array_pos]
      puts "<item uuid='#{local_array_pos}' arg='#{local_array_pos}' valid='yes'>"
      puts "<title><![CDATA[#{template_title}]]></title>"
      puts '<icon>icon.png</icon>'
      puts '</item>'
    end
  end

  puts '</items>'
end

def remote_info
  puts "<?xml version='1.0'?><items>"

  if remote_list.empty?
    puts "<item uuid='none' arg='none' valid='no'>"
    puts '<title>List templates (rtml)</title>'
    puts '<subtitle>You need to add some remote templates, first</subtitle>'
    puts '<icon>icon.png</icon>'
    puts '</item>'
  else
    remote_list.each_index do |remote_array_pos|
      template_subtitle = remote_list[remote_array_pos]
      template_title = File.basename(template_subtitle)
      puts "<item uuid='#{remote_array_pos}' arg='#{remote_array_pos}' valid='yes'>"
      puts "<title><![CDATA[#{template_title}]]></title>"
      puts "<subtitle><![CDATA[#{template_subtitle}]]></subtitle>"
      puts '<icon>icon.png</icon>'
      puts '</item>'
    end
  end

  puts '</items>'
end

# run a _templatesmanagerscript.* in the copied directory
def local_script_run(location)
  tm_script = Dir.entries(location).find { |item| item =~ /_templatesmanagerscript\./ }

  return unless tm_script
  Dir.chdir(location)
  system('./' + tm_script)
end

# Copy files and directories directly
def local_put(local_array_pos)
  template_title = local_list[local_array_pos]
  item_location = Local_templates + template_title
  FileUtils.cp_r(item_location, finder_dir)

  # run _templatesmanagerscript.*, if a directory was copied
  dest_location = finder_dir + template_title
  local_script_run(dest_location) if File.directory?(dest_location)
end

# If source is a directory, copy what's inside of it
def local_put_files_only(local_array_pos)
  item_location = Local_templates + local_list[local_array_pos]

  # if used on a file, give a warning
  if File.file?(item_location)
    notification('This option should only be used on directories')
    abort 'This option should only be used on directories'
  else
    FileUtils.cp_r(Dir[item_location + '/*'], finder_dir)

    # run _templatesmanagerscript.*
    local_script_run(finder_dir)
  end
end

def remote_put(remote_array_pos)
  url = remote_list[remote_array_pos].gsub(/\n$/, '')
  file_name = File.basename(url)
  File.write(finder_dir + file_name, Net::HTTP.get(URI.parse(url)))
end

def remote_print(remote_array_pos)
  url = remote_list[remote_array_pos].gsub(/\n$/, '')
  print Net::HTTP.get(URI.parse(url))
end
