$:.unshift File.expand_path('../../lib', __FILE__)
require 'stackprof'
require 'stackprof/middleware'
require 'minitest/autorun'
require 'mocha/setup'

class StackProf::MiddlewareTest < MiniTest::Test

  def test_path_default
    StackProf::Middleware.new(Object.new)

    assert_equal 'tmp', StackProf::Middleware.path
  end

  def test_path_custom
    StackProf::Middleware.new(Object.new, { path: '/foo' })

    assert_equal '/foo', StackProf::Middleware.path
  end

  def test_save_default
    StackProf::Middleware.new(Object.new)

    StackProf.stubs(:results).returns({ mode: 'foo' })
    FileUtils.expects(:mkdir_p).with('tmp')
    File.expects(:open).with(regexp_matches(/^tmp\/stackprof-foo/), 'wb')

    StackProf::Middleware.save
  end

  def test_save_custom
    StackProf::Middleware.new(Object.new, { path: '/foo' })

    StackProf.stubs(:results).returns({ mode: 'foo' })
    FileUtils.expects(:mkdir_p).with('/foo')
    File.expects(:open).with(regexp_matches(/^\/foo\/stackprof-foo/), 'wb')

    StackProf::Middleware.save
  end

  def test_save_should_use_a_proc_if_passed
    StackProf.stubs(:results).returns({ mode: 'foo' })
    FileUtils.expects(:mkdir_p).with('/foo').never
    File.expects(:open).with(regexp_matches(/^\/foo\/stackprof-foo/), 'wb').never

    proc_called = false
    StackProf::Middleware.new(Object.new, saviour: Proc.new{ proc_called = true })
    StackProf::Middleware.save
    assert proc_called
  end

  def test_enabled_should_use_a_proc_if_passed
    env = {}

    StackProf::Middleware.new(Object.new, enabled: Proc.new{ false })
    refute StackProf::Middleware.enabled?(env)

    StackProf::Middleware.new(Object.new, enabled: Proc.new{ true })
    assert StackProf::Middleware.enabled?(env)
  end

  def test_enabled_should_use_a_proc_if_passed_and_use_the_request_env
    enable_proc = Proc.new {|env| env['PROFILE'] }

    env = Hash.new { false }
    StackProf::Middleware.new(Object.new, enabled: enable_proc)
    refute StackProf::Middleware.enabled?(env)

    env = Hash.new { true }
    StackProf::Middleware.new(Object.new, enabled: enable_proc)
    assert StackProf::Middleware.enabled?(env)
  end

  def test_raw
    StackProf::Middleware.new(Object.new, raw: true)
    assert StackProf::Middleware.raw
  end

  def test_enabled_should_override_mode_if_a_proc
    proc_called = false
    middleware = StackProf::Middleware.new(proc {|env| proc_called = true}, enabled: Proc.new{ [true, 'foo'] })
    env = Hash.new { true }
    enabled, mode = StackProf::Middleware.enabled?(env)
    assert enabled
    assert_equal 'foo', mode

    StackProf.expects(:start).with({mode: 'foo', interval: StackProf::Middleware.interval, raw: false})
    StackProf.expects(:stop)

    middleware.call(env)
    assert proc_called
  end
end
