require 'uri'
require 'net/http'
require 'nokogiri'

class FacebookProfileScraper

  ELEMENT_CONFIG = {
    name: {
      selector: '#fb-timeline-cover-name',
      value: -> (element) { element.text }
    },
    picture_url: {
      selector: 'img.profilePic.img',
      value: -> (element) { element.attr('src') }
    },
    city: {
      selector: '#pagelet_hometown span._50f5._50f7',
      value: -> (element) { element.css('a').text }
    },
    about: {
      selector: '#pagelet_bio span._c24._50f4',
      value: -> (element) { element.text }
    },
    quote: {
      selector: '#pagelet_quotes span._c24._50f4',
      value: -> (element) { element.text }
    }
  }

  attr_accessor :parsed_page, :response, :profile_url, :username

  def initialize(facebook_profile_url)
    begin
      self.response = Net::HTTP.get_response(URI(facebook_profile_url))
      self.profile_url = facebook_profile_url
      self.username = URI(profile_url).path.split('/').last
      if response.code.to_i == 302
        self.profile_url = response.to_hash['location'].first
        self.username = URI(profile_url).path.split('/').last
        self.response = Net::HTTP.get_response(URI(profile_url))
      end
      self.parsed_page = Nokogiri::HTML(response.body)
    rescue StandardError => e
      warn "Couldn't get profile: #{e} -- #{facebook_profile_url}"
      raise
    end

    self
  end

  def work
    parsed_page
      .css('#pagelet_eduwork')
      .css('[data-pnref="work"]')
      .css('ul.fbProfileEditExperiences li.experience')
      .map do |li|
        company = li.css('a').text
        title, dates, location = li.css('div.fsm').text.split("\u00B7").map(&:strip)
        {
          company: company,
          title: title,
          dates: dates.split(' to '),
          location: location
        }
      end
  end

  def education
    parsed_page
      .css('#pagelet_eduwork')
      .css('[data-pnref="edu"]')
      .css('ul.fbProfileEditExperiences li.experience')
      .map do |li|
        school = li.css('a').text
        class_year, degree, majors = li.css('div.fsm').text.split("\u00B7").map(&:strip)
        {
          school: school,
          class_year: class_year,
          degree: degree,
          majors: majors.to_s.split(';').map(&:strip)
        }
      end
  end

  # def method_missing(method, *arguments, &block)
  def method_missing(method)
    element_config = ELEMENT_CONFIG[method.to_sym]

    # Nokogiri always return an array of elements
    element = parsed_page.css(element_config[:selector]).first

    # Return if not found
    return unless element

    # Get value
    value = element_config[:value].call(element)

    # Don't allow empty string
    value.empty? ? nil : value
  end

end
