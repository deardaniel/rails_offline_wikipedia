
WikiDb.setup do |config|
    lib = "#{RAILS_ROOT}/lib"
    
    config.max_search_results = 100
    config.page_cache_size    = 200
    config.index_toc_file     = "#{lib}/wiki_db/wikidb.index_toc"
    config.index_file         = "#{lib}/wiki_db/wikidb.index"
    config.bz2table_file      = "#{lib}/wiki_db/wikidb.bz2t"
    config.wiki_xml_dump      = "#{lib}/wiki_db/enwiki-latest-pages-articles.xml.bz2"
    config.seek_bunzip_cmd    = "#{lib}/wiki_db/seek-bunzip"
end
