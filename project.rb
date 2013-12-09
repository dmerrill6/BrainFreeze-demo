# == Schema Information
#
# Table name: projects
#
#  id                      :integer          not null, primary key
#  title                   :string(255)
#  summary                 :string(255)
#  documentation           :string(255)
#  user_id                 :integer
#  attachment_file_name    :string(255)
#  attachment_content_type :string(255)
#  attachment_file_size    :integer
#  attachment_updated_at   :datetime
#

class Project < ActiveRecord::Base

	attr_accessible :title, :summary, :documentation
  	has_many :user_project_karmas
	belongs_to :user
	has_and_belongs_to_many :tags
	has_many :followers
	has_many :comments
	has_many :filenames
    validates_presence_of :title
	def tag_names
		tags.map {|t| t.name}.join(', ')
	end
	def self.coderay(text,ext)
		if(ext==".rb")
	    	return CodeRay.scan(text,:ruby).div(:line_numbers => :table)
    	else
    		return "Format not supported"
    	end
	end

	def update_tags!(tag_names, user_id)
		tags_array = tag_names.is_a?(Array) ? tag_names : tag_names.split(/ *, */)
		tags_array.each do |t|
			curr = Tag.find_or_create_by_name(t)
			curr.update_attribute(:user_id, user_id) unless (curr.user != nil)
			tags << curr unless(tags.exists?(curr))
		end
	end

	def tags_to_s
		result = ""
		if(tags.count > 0)
		  	for i in 0..(tags.count-2)
				result += tags[i].name + ", "
			end
			result += tags[-1].name
		end
		return result
	end

	def followers_to_s
		result = ""
		if(followers.count > 0)
		  	for i in 0..(followers.count-2)
				result += followers[i].user.email + ", "
			end
			result += followers[-1].user.email
		end
		return result
	end

	def toggle_following! (user)
		curr  = followers.where(user_id: user.id)
		is_following = curr.count > 0
		if(!is_following)
			f = followers.new()
			f.update_attribute(:user, user)
		else
			curr.first.destroy
		end
	end

	def is_following (user)
		return followers.where(user_id: user.id).count > 0
	end

	def save_file(upload, user_id)
	 	name =  upload.original_filename		
	    directory = "assets/private/" + id.to_s
	    FileUtils.mkdir_p directory
	    # create the file path
	    path = File.join(directory, name)
	    f =  Filename.new()
	    f.filename = name
	    f.project = self
	    f.user = User.find(user_id)
	    f.save
	    # write the file
	    File.open(path, "wb") { |f| f.write(upload.read) } 
  end

  def update_file(upload, filename_id)
	 	name =  upload.original_filename		
	    directory = "assets/private/" + id.to_s
	    FileUtils.mkdir_p directory
	    # create the file path
	    path = File.join(directory, name)
	    f =  Filename.find(filename_id)
	    f.filename = name
	    f.project = self
	    f.save
	    # write the file
	    File.open(path, "wb") { |f| f.write(upload.read) } 
  end

  def self.getHotProjects (ammountOfProjects, daysAgo)
  		query = Project.where("created_at > ?", Date.today - daysAgo.days).order("karma DESC").limit(ammountOfProjects)
  		if(query.count < ammountOfProjects)
  			query = query + Project.order("karma DESC").limit(3)
  		end
  		return query[0..2]
  end

  def send_mails
  	flwers = User.where(:id => followers.pluck(:user_id))
	flwers.each do |f|
        UserMailer.project_updated_following(f, self).deliver

  	end
  	favorites = User.where(:id => Favorite.where(:project_id => self.id).pluck(:user_id)).where('id not in (?)', followers.pluck(:user_id) + [0])
  	favorites.each do |f|
  		UserMailer.project_updated_favorite(f, self).deliver
  	end

  end

  def organization_name
  	if organization_id != nil
  		Organization.find(organization_id).name
  	else
  		"none"
  	end
  end


end
