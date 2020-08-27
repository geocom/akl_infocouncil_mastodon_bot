ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __FILE__)
require "rubygems"
require 'bundler/setup'
require 'open-uri'
Bundler.require
DAY_ENDINGS = ["", "st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th", "th", "st"]
index = Nokogiri::HTML.parse(open('http://infocouncil.aucklandcouncil.govt.nz/'), nil, "UTF-8")
tootable_items = []
logfile = "#{Dir.pwd}/log.log"
disable_tooting = File.read("#{Dir.pwd}/api_key.txt").split("\n")[1].downcase == "true" ##Option to disable tooting out. Good for testing or for inital import so we dont go over API limits. Will still create the folders and log just wont post
interspace = File.read("#{Dir.pwd}/api_key.txt").split("\n")[2].to_i #looks like a issue with imagemagick is causing the text to overlap this will allow you to set a interspace. if overlapping set to the font size.

mastodon_key = File.read("#{Dir.pwd}/api_key.txt").split("\n")[0]

client = Mastodon::REST::Client.new(base_url: 'https://botsin.space', bearer_token: mastodon_key, timeout: {connect: 10, read:20, write: 60})
files_added = []
if File.exist?(logfile) == false
	File.open(logfile, 'w') { |file| file.write("Beginning New LogFile") }
end
if index.blank? == false
	if not Dir.exist?("#{Dir.pwd}/meetings")
		`mkdir #{Dir.pwd}/meetings`
	end

	meetings = []

	index.css('.bpsGridMenuItem', '.bpsGridMenuAltItem').each do |link|
		sanitised_name = link.css('.bpsGridCommittee')[0].children.first.content.gsub("Addendum", "").strip()
		address = link.css('.bpsGridCommittee span')[0].content.gsub("\r\n", " ")
		meetings << [Date.parse( link.css('.bpsGridDate')[0].inner_html.split("<br>")[0]), sanitised_name, link.css('.bpsGridAgenda')[0], link.css('.bpsGridAttachments')[0], link.css('.bpsGridMinutes')[0], link.css('.bpsGridMinutesAttachments')[0], address]
	end
	#puts meetings
	meetings.each do |item|

		dated_path = "#{Dir.pwd}/meetings/#{item[0].strftime("%Y-%m-%d")}"
		meeting_path = "#{dated_path}/#{item[1].downcase.gsub(" ", "")}"
		if not Dir.exist?(dated_path)
			`mkdir #{dated_path}`
		end

		##Many local board/pannels are in Maori which has some charaters that wont work with file systems.So we need to replace those charaters them.
		foldername = item[1].scrub.downcase.gsub(/[^0-9A-Za-z.\-]/, '_')

		if not File.exist?("#{dated_path}/#{foldername}")
			`mkdir #{dated_path}/#{foldername}`
		end
		##Now that this meeting has been registered we need to tell it what has been uploaded so that we can toot it out. and save it so that next time we won't toot the same thing.
		agenda_items = []
		agenda_attachments = []
		minutes = []
		minutes_attachments = []

		agenda_files_added = []
		agenda_attachments_files_added = []
		minutes_files_added = []
		minutes_attachements_files_added = []

		changes_to_folder = [item[0], item[1]]
		files_changed = []

		item[2].css("a").each do |item|
			item_filename = item['href'].split("/").last
			##Has this file already been scrapped
			if not File.exist?("#{dated_path}/#{foldername}/#{item_filename}.item")
				##Write the file so we know its added
				File.open("#{dated_path}/#{foldername}/#{item_filename}.item", 'w') { |file| file.write("") }
				agenda_files_added << "#{dated_path}/#{foldername}/#{item_filename}.item"
				agenda_items << item
			end
		end

		item[3].css("a").each do |item|
			item_filename = item['href'].split("/").last
			##Has this file already been scrapped
			if not File.exist?("#{dated_path}/#{foldername}/#{item_filename}.item")
				##Write the file so we know its added
				File.open("#{dated_path}/#{foldername}/#{item_filename}.item", 'w') { |file| file.write("") }

				agenda_attachments_files_added << "#{dated_path}/#{foldername}/#{item_filename}.item"

				agenda_attachments << item
			end
		end

		item[4].css("a").each do |item|
			item_filename = item['href'].split("/").last
			##Has this file already been scrapped
			if not File.exist?("#{dated_path}/#{foldername}/#{item_filename}.item")
				##Write the file so we know its added
				File.open("#{dated_path}/#{foldername}/#{item_filename}.item", 'w') { |file| file.write("") }

				minutes_files_added << "#{dated_path}/#{foldername}/#{item_filename}.item"

				minutes << item
			end
		end
		item[5].css("a").each do |item|
			item_filename = item['href'].split("/").last
			##Has this file already been scrapped
			if not File.exist?("#{dated_path}/#{foldername}/#{item_filename}.item")
				##Write the file so we know its added
				File.open("#{dated_path}/#{foldername}/#{item_filename}.item", 'w') { |file| file.write("") }

				minutes_attachements_files_added << "#{dated_path}/#{foldername}/#{item_filename}.item"

				minutes_attachments << item
			end
		end
		changes_to_folder << agenda_items
		changes_to_folder << agenda_attachments
		changes_to_folder << minutes
		changes_to_folder << minutes_attachments

		files_changed << agenda_files_added
		files_changed << agenda_attachments_files_added
		files_changed << minutes_files_added
		files_changed << minutes_attachements_files_added

		if agenda_items.count > 0 or agenda_attachments.count > 0 or minutes.count > 0 or minutes_attachments.count > 0
			puts "#{item[0]} #{item[1]}"
			tootable_items << changes_to_folder
			files_added << files_changed
		end
	end
	tootable_items.each_with_index do |item, tootable_index|
		 formatted_toot = []
     textcount = []
		 hashtag_types_included = []
		 title_type = []
		 addendum = ""
		 toot_image = ""
		 if not item[2][0] == nil
			 if item[2][0].content.include?("Addendum")
				 addendum = " Addendum"
				 hashtag_types_included << "#CouncilAgendaAddendum"
			 else
				 hashtag_types_included << "#CouncilAgenda"
			 end
		 end
		 if item[2].count > 0
			 title_type << "Agenda#{addendum}"
		 end
		 if item[3].count > 0
			 title_type << "Agenda#{addendum} Attachments"
		 end
		 if item[4].count > 0
			 title_type << "Minutes"
			 hashtag_types_included << "#CouncilMinutes"
		 end
		 if item[5].count > 0
			 title_type << "Minutes Attachments"
		 end
		  formatted_toot << "#{item[1]} #{title_type.join(" & ")} for the #{item[0].mday}#{DAY_ENDINGS[item[0].mday]} of #{item[0].strftime("%B %Y")}"
      textcount << "#{item[1]} #{title_type.join(" & ")} for the #{item[0].mday}#{DAY_ENDINGS[item[0].mday]} of #{item[0].strftime("%B %Y")}"
		 ##This deals with Agendas
		 if not item[2].count <= 0

			 item[2].each do |url|
				if url['href'].include?(".PDF") or url['href'].include?(".pdf")
			 		formatted_toot << "Agenda PDF: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
          textcount << "Agenda PDF: indistinguishablenesses"
				else
					formatted_toot << "Agenda HTML: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
          textcount << "Agenda HTML: indistinguishablenesses"

					agenda = Nokogiri::HTML(open("http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last.gsub("_WEB", "_BMK")}"))

					agenda_items = []

					agenda.css(".bpsNavigationListItem a.bpsNavigationListItem").each do |item|
					  if not item == nil
					  	if item.parent.parent.parent.values.include?("bpsNavigationBody")
								a = item.content.split("\t")

								justified_text = []

								if a.length == 1
									# only 1 item unable to do any of the testing below so will just put the line in as is
									justified_text << a.first.strip
								else
									if not a.first.to_i > 0
										#is not a number
										justified_text << a.first.strip
									end

									justified_text << a.last.strip
								end
						    agenda_items << ("#{justified_text.join("")}").gsub(/[\r\n]+/, ' ')
							end
					  end
					end


#					agenda.css(".TOCCell").each do |item|
#					  if not item == nil
#					    a = item.content.split("\u00A0")
#					    a.delete("")
#					    if a[1] != "" && a[1] != nil
#					      agenda_items << (a[1]).gsub(/[\r\n]+/, ' ')
#					    end
#					  end
#					end
					open(logfile, 'a') { |f|
					  f.puts agenda_items.join("\n")
					}
					if not Dir.exist?("#{Dir.pwd}/images")
						`mkdir #{Dir.pwd}/images`
					end

					#puts "convert -background white -fill navy -pointsize 15 -size 800x caption:'\\n#{agenda_items.join("\\n").gsub("'", "\'\\\\'\'")}' #{Dir.pwd}/images/#{url['href'].split("/").last}.png"
					#`convert -background white -fill navy -pointsize 15 -size 800x caption:'\\n#{agenda_items.join("\\n").gsub("'", "\'\\\\'\'")}' #{Dir.pwd}/images/#{url['href'].split("/").last}.png`
					title_tmp_filename = "top_#{Time.now.to_i}"
					contents_tmp_filename = "bottom_#{Time.now.to_i}"
          height_size = (15 * agenda_items.size) + 15
					`convert -background white -fill navy -gravity center -pointsize 15 -interline-spacing #{interspace} -size 800x50 caption:'\\nTable of Contents\\n#{agenda.title}' #{Dir.pwd}/images/#{title_tmp_filename}.png`
					`convert -background white -fill navy -pointsize 15 -interline-spacing #{interspace} -size 800x#{height_size} caption:'\\n#{agenda_items.join("\\n").gsub("'", "\'\\\\'\'")}' #{Dir.pwd}/images/#{contents_tmp_filename}.png`

					`convert #{Dir.pwd}/images/#{title_tmp_filename}.png #{Dir.pwd}/images/#{contents_tmp_filename}.png -append #{Dir.pwd}/images/#{url['href'].split("/").last}.png`
					`rm -f	#{Dir.pwd}/images/#{title_tmp_filename}.png`
					`rm -f	#{Dir.pwd}/images/#{contents_tmp_filename}.png`

          toot_image = "#{Dir.pwd}/images/#{url['href'].split("/").last}.png"
				end
			end
		 end
		 ##agenda attachments
		 if not item[3].count <= 0
			 item[3].each do |url|
				 if url['href'].include?(".PDF") or url['href'].include?(".pdf")
					 formatted_toot << "Attachments PDF: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
           textcount << "Attachments PDF: indistinguishablenesses"
				 else
					 formatted_toot << "Attachments HTML: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
           textcount << "Attachments HTML: indistinguishablenesses"
				 end
			 end
		 end
		 ##Minutes
		 if not item[4].count <= 0
			item[4].each do |url|
				if url['href'].include?(".PDF") or url['href'].include?(".pdf")
			 		formatted_toot << "Minutes PDF: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
          textcount << "Minutes PDF: indistinguishablenesses"
				else
					formatted_toot << "Minutes HTML: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
          textcount << "Minutes HTML: indistinguishablenesses"
				end
			end
		 end
		 ##Minutes attachments
		 if not item[5].count <= 0
		 item[5].each do |url|
			 if url['href'].include?(".PDF") or url['href'].include?(".pdf")
				 formatted_toot << "Attachments PDF: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
         textcount << "Attachments PDF: indistinguishablenesses"
			 else
				 formatted_toot << "Attachments HTML: http://infocouncil.aucklandcouncil.govt.nz/#{url['href'].split("?URL=").last}"
         textcount << "Attachments HTML: indistinguishablenesses"
			 end
		 end
		end
		 formatted_toot << "#AucklandCouncil #PublicRecords #{hashtag_types_included.join(" ")}"
     textcount << "#AucklandCouncil #PublicRecords #{hashtag_types_included.join(" ")}"
		 open(logfile, 'a') { |f|
		   f.puts "##Toot Starts"
		 }
		 open(logfile, 'a') { |f|
		   f.puts formatted_toot.join("\n")
		 }
		 begin
       if textcount.join("\n").size > 500
         raise "Toot too long"
       end
       if disable_tooting == false
  		 	 if toot_image == ""
          client.create_status(formatted_toot.join("\n"), {:language => "en"})
  			 else
           puts toot_image
          media = client.upload_media(toot_image, {:focus => "-1, -1"})
          client.create_status(formatted_toot.join("\n"), {:language => "en", :media_ids => [media.id]})
  			 end
       end
		 rescue => e
			 if e.message.include?("Toot too long")
			 	 open(logfile, 'a') { |f|
			 	   f.puts "toot needs to be shorter"
			 	 }
				 begin
           if (formatted_toot.first(formatted_toot.size - 1)).join("\n").size > 500
             raise "Toot too long"
           end
           if disable_tooting == false
             if toot_image == ""
              client.create_status((formatted_toot.first(formatted_toot.size - 1)).join("\n"), {:language => "en"})
      			 else
              media = client.upload_media(toot_image, {:focus => "-1, -1"})
              client.create_status((formatted_toot.first(formatted_toot.size - 1)).join("\n"), {:language => "en", :media_ids => [media.id]})
      			 end
           end
				 rescue => e
					 if e.message.include?("Toot needs to be a bit shorter")
					 	 open(logfile, 'a') { |f|
					 	   f.puts "toot still needs to be shorter splitting HTML and PDF into sep toots"
					 	 }
					 	 begin
					 	 	toot_html = []
					 	 	toot_pdf = []
					 	 	toot_html << formatted_toot[1]
					 	 	toot_pdf << formatted_toot[1]
					 	 	formatted_toot.each_with_index do |toot_content, index|
				 	 			if toot_content.include?("HTML")
				 	 				toot_html << toot_content
				 	 			elsif toot_content.include?("PDF")
				 	 				toot_pdf << toot_content
				 	 			else
				 	 				toot_html << toot_content
				 	 				toot_pdf << toot_content
					 	 		end
					 	 	end
              if disable_tooting == false
                if toot_image == ""
                 client.create_status(toot_html.join("\n"), {:language => "en"})
                 client.create_status(toot_pdf.join("\n"), {:language => "en"})
         			 else
                 html_media = client.upload_media(toot_image, {:focus => "-1, -1"})
                 pdf_media = client.upload_media(toot_image, {:focus => "-1, -1"})

                 client.create_status(toot_html.join.join("\n"), {:language => "en", :media_ids => [html_media.id]})
                 client.create_status(toot_pdf.join("\n"), {:language => "en", :media_ids => [pdf_media.id]})
         			 end
              end
					 	 rescue => e
					 		 open(logfile, 'a') { |f|
					 		   f.puts e.message
                 f.puts e.backtrace

								 files_added[tootable_index].each do |item|
									 item.each do |file|
										 `rm -f #{file}`
									 end
								 end
					 		 }
					 	 end
					 else
					 	 open(logfile, 'a') { |f|
					 	   f.puts e.message
               f.puts e.backtrace
							 files_added[tootable_index].each do |item|
								 item.each do |file|
									 `rm -f #{file}`
								 end
							 end
					 	 }
					 end
				 end
			 else
				 open(logfile, 'a') { |f|
				   f.puts e.message
           f.puts e.backtrace
					 files_added[tootable_index].each do |item|
						 item.each do |file|
							 `rm -f #{file}`
						 end
					 end
				 }
			 end
		 end
		 open(logfile, 'a') { |f|
		 	   f.puts "##Toot Ends"
		 }
		 puts "##Toot Ends"
	end
end
