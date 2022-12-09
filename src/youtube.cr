class Castblock::Youtube
  def initialize(@api_key : String? = nil)
  end

  # Get the id of a video given its author name and title.
  def get_video_id(author : String, title : String) : String?
    if !@api_key.nil?
      get_video_id_from_api(author, title)
    else
      get_video_id_from_scrapping(author, title)
    end
  end

  private def get_video_id_from_api(author : String, title : String) : String?
  end

  private def get_video_id_from_scrapping(author : String, title : String) : String?
  end
end
