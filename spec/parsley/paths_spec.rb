require 'parsley/paths'

describe Parsley::Path::ArchiveRelative do
  describe '#initialize' do
    it 'sets the root and the path' do
      path = Parsley::Path::ArchiveRelative.new('orsr/2013/413.html', '/archive')
      path.full_path.should == '/archive/orsr/2013/413.html'
    end
  end

  describe '#dirname' do
    it 'returns parent archive-relative directory' do
      path = Parsley::Path::ArchiveRelative.new('orsr/2013/413.html', '/archive')
      path.dirname.should == Parsley::Path::ArchiveRelative.new('orsr/2013', '/archive')
    end
  end

  describe '#append' do
    it 'creates new archive-relative path by appending' do
      path = Parsley::Path::ArchiveRelative.new('orsr/2013/', '/archive')
      path.append('subdir').should == Parsley::Path::ArchiveRelative.new('orsr/2013/subdir', '/archive')
    end
  end
end

describe Parsley::Path::Full do
  describe '#initialize' do
    it 'uses the provided path' do
      path = Parsley::Path::Full.new('/tmp/foo')
      path.full_path.should == '/tmp/foo'
    end
  end

  describe '#dirname' do
    it 'returns parent full-path directory' do
      path = Parsley::Path::Full.new('/tmp/foo/raw.zip')
      path.dirname.should == Parsley::Path::Full.new('/tmp/foo')
    end
  end

  describe '#append' do
    it 'creates new full-path  by appending' do
      path = Parsley::Path::Full.new('/tmp/foo/')
      path.append('subdir').should == Parsley::Path::Full.new('/tmp/foo/subdir')
    end
  end
end
