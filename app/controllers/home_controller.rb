# coding: utf-8

require 'open-uri'

class HomeController < ApplicationController
  include WikiCloth
  
  def index
    @out = request.inspect
  end
  
  def view
    if params[:page].start_with? "File:"
      file = "#{::Rails.root.to_s}/image_cache/#{params[:page][(5..-1)]}"
      if !File.exists?(file)
        send_data '', :type => 'text/html; charset=utf-8', :status => 404
        return
      end
      
      extname = File.extname(file)[1..-1].downcase
      mime_type = Mime::Type.lookup_by_extension(extname)
      content_type = mime_type.to_s unless mime_type.nil?
      
      send_file "#{::Rails.root.to_s}/image_cache/#{params[:page][(5..-1)]}", :disposition => 'inline', :type => content_type
      return
    end
    
    @wiki = WikiDb::Database.new.get_page(params[:page])#.gsub(/\|title=(.*?)(\}|\|)/) { |m| m.gsub '[','&#92;' }
    link_handler = LinkHandler.new
    @html = WikiCloth.new({
      :data => @wiki,
      :link_handler => link_handler
      }).to_html.gsub(/<pre>\s*<\/pre>/, '').gsub(/<p>\s*<\/p>/, '')
    @resources = link_handler.resources
      
    if params[:templated]
      h = LinkHandler.new
      h.use_templates = true
      @templated = WikiCloth.new({
          :data => @wiki,
          :link_handler => h
          }).to_html.gsub(/<pre>\s*<\/pre>/, '').gsub(/<p>\s*<\/p>/, '')
    end
  end
end


class LinkHandler < WikiCloth::WikiLinkHandler
  attr_accessor :use_templates
  attr_reader :resources
  
  def initialize
    @resources = []
  end
  
  def use_templates
    @use_templates || false
  end
  
  def template template_name
    return unless use_templates
    
    return 'article' if template_name.downcase == 'namespace'
    return params[:page] if template_name.upcase == template_name
    return params[:page] if ['documentation', 'pagetype', 'R from other template', 'pp-template'].include? template_name.downcase
    
    if template_name.downcase == 'main'
      return '<div class="rellink relarticle mainarticle">Main article: <a href="/wiki/{{{1}}}" title="{{{1}}}">{{{1}}}</a></div>'
    end
    WikiDb::Database.new.get_page("Template:#{template_name}", true) || ''
  end
  
  def wiki_image resource, options
    p resource
    p options
    exists = File.exists?("#{::Rails.root.to_s}/image_cache/#{resource}")
    resources << { :name => resource, :status => exists ? 'loaded' : 'not-loaded' }
    Delayed::Job.enqueue(DownloadImageJob.new(resource, "http://en.wikipedia.org/wiki/File:#{URI.escape resource}")) unless exists
    super "/File:#{resource}", options
  end
  
  def url_for(page)
    (page.nil? || page.length < 1) ? '' : "/#{page[0].upcase}#{page[1..-1]}"
  end
  
  def link_attributes_for(page)
     { :href => url_for(page) }
  end
  
  def toc_children(sec_tocnum, children)
    ret = "<ul class=\"\">"
    children.each_with_index do |child, child_tocnum|
      tocnum = "#{sec_tocnum}.#{child_tocnum+1}"
      ret += "<li><a href=\"##{child.id}\"><span class=\"tocnumber\">#{tocnum}</span> <span class=\"toctext\">#{child.title}</a>"
      ret += toc_children(tocnum, child.children) unless child.children.empty?
      ret += "</li>"
    end
    "#{ret}</ul>"
  end

  def toc(sections)
    ret = "<table id=\"toc\" class=\"toc\" summary=\"Contents\"><tr><td><div style=\"font-weight:bold\">Table of Contents</div><ul class=\"tocsection\">"
    sections[0].children.each_with_index do |section,i|
      tocnum = "#{i+1}"
      ret += "<li><a href=\"##{section.id}\"><span class=\"tocnumber\">#{tocnum}</span> <span class=\"toctext\">#{section.title}</span></a>"
      ret += toc_children(tocnum, section.children) unless section.children.empty?
      ret += "</li>"
    end
    "#{ret}</ul></td></tr></table>"
  end
end
