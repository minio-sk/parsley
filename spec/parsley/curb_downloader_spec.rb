require 'parsley'

describe Parsley::CurbDownloader do
  it 'passes user agent to curl request' do
    headers = double(:headers)
    headers.should_receive(:[]=).with('User-Agent', :something)

    yield_options = double(:options).as_null_object
    yield_options.should_receive(:headers).and_return(headers)

    curl = double.as_null_object
    curl.should_receive(:get).with('url').and_yield(yield_options).and_return(curl)

    stub_const('Curl', curl)

    described_class.download('url', {useragent: :something})
  end

  it 'passes cookies to curl request' do
    setup = double(:setup).as_null_object
    setup.should_receive(:cookies=).with('sid=123; abc=321;')

    curl = double.as_null_object
    curl.should_receive(:get).with('url').and_yield(setup).and_return(curl)

    stub_const('Curl', curl)

    described_class.download('url', {cookies: {sid: 123, abc: 321}})
  end

  it 'passes ssl_verify_peer to curl request' do
    setup = double(:setup).as_null_object
    setup.should_receive(:ssl_verify_peer=).with(false)

    curl = double.as_null_object
    curl.should_receive(:get).with('url').and_yield(setup).and_return(curl)

    stub_const('Curl', curl)

    described_class.download('url', ssl_verify_peer: false)
  end
end
