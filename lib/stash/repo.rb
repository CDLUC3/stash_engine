module Stash
  module Repo
    Dir.glob(File.expand_path('../repo/*.rb', __FILE__)).sort.each(&method(:require))
  end
end
