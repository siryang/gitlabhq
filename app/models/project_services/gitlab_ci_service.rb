# == Schema Information
#
# Table name: services
#
#  id                    :integer          not null, primary key
#  type                  :string(255)
#  title                 :string(255)
#  project_id            :integer
#  created_at            :datetime
#  updated_at            :datetime
#  active                :boolean          default(FALSE), not null
#  properties            :text
#  template              :boolean          default(FALSE)
#  push_events           :boolean          default(TRUE)
#  issues_events         :boolean          default(TRUE)
#  merge_requests_events :boolean          default(TRUE)
#  tag_push_events       :boolean          default(TRUE)
#

class GitlabCiService < CiService
  prop_accessor :project_url, :token
  validates :project_url, presence: true, if: :activated?
  validates :token, presence: true, if: :activated?

  after_save :compose_service_hook, if: :activated?

  def compose_service_hook
    hook = service_hook || build_service_hook
    hook.url = [project_url, "/build", "?token=#{token}"].join("")
    hook.save
  end

  def supported_events
    %w(push tag_push)
  end

  def execute(data)
    return unless supported_events.include?(data[:object_kind])

    service_hook.execute(data)
  end

  def commit_status_path(sha, ref)
    project_url + "/refs/#{ref}/commits/#{sha}/status.json?token=#{token}"
  end

  def get_ci_build(sha, ref)
    @ci_builds ||= {}
    @ci_builds[sha] ||= HTTParty.get(commit_status_path(sha, ref), verify: false)
  end

  def commit_status(sha, ref)
    response = get_ci_build(sha, ref)

    if response.code == 200 and response["status"]
      response["status"]
    else
      :error
    end
  end

  def commit_coverage(sha, ref)
    response = get_ci_build(sha, ref)

    if response.code == 200 and response["coverage"]
      response["coverage"]
    end
  end

  def build_page(sha, ref)
    project_url + "/refs/#{ref}/commits/#{sha}"
  end

  def builds_path
    project_url + "?ref=" + project.default_branch
  end

  def status_img_path
    project_url + "/status.png?ref=" + project.default_branch
  end

  def title
    'GitLab CI'
  end

  def description
    'Continuous integration server from GitLab'
  end

  def to_param
    'gitlab_ci'
  end

  def fields
    [
      { type: 'text', name: 'token', placeholder: 'GitLab CI project specific token' },
      { type: 'text', name: 'project_url', placeholder: 'http://ci.gitlabhq.com/projects/3' }
    ]
  end
end
