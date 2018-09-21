# Harmoni

Harmoni is a very simple library made for keeping configuration files on disk in sync with configuration loaded into memory. This provides capabilities to more easily support hot loading of configuration or settings for running applications. It also adds several goodies to make interacting with your configurations easier, whether they are synchronized to a file or not.

Harmoni currently supports YAML and JSON files but may grow to include other formats in the future (as necessary).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'harmoni'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install harmoni

## Usage
First `require 'harmoni'`

Using Harmoni is very simple. To create or track a new configuration, you can do any of the following:

```
# The simplest way to spin up a new config. This is not synchronized
# with a file on disk unless you pass sync: true
Harmoni.build('my-config.json')

# Same as :build but automatically sets sync: true so that the file on disk
# will be in sync with the settings in memory
Harmoni.sync('your-config.yml')

# Create a new instace of config. Specifying type: yaml will return and instance
# of Harmoni::Config::YAML instead of the barebones Harmoni::Config
Harmoni::Config.new(path: 'settings.yml', type: :yaml)

# Same as the example above but is called specifically on the YAML class
Harmoni::YAML.new(path: 'settings.yml')
```

Both Harmoni.build and Harmoni.sync will automatically detect the appropriate adapter to use based on the path provided. If the path already exists, the adapters will ensure the content fits their parsing. So a file named bad-idea.json that is actually YAML will appropriately be detected as YAML, despite the extension mismatch.

If the file does not already exist, the adapter will be determined based off of the extension. So passing a path of "config.json" will create an instance of Harmoni::JSON. The file will then automatically be created the first time :save is invoked.

If for any reason the auto detection fails or you do not want to rely on it, you can also specify the adapter to use by passing the keyword :type to the constructor. The current adapters available can be specified as type: :yaml or type: :json.

### Setting and Getting Values

Harmoni heavily uses BBLib::HashPath under the hood to manage your configuration. This means you can use the hash path notation to set and get nested values (even recursively!). For an example, look at the code below.

#### Get
```
conf = Harmoni.sync('/tmp/settings.yml', configuration: { settings: { general: { user: 'bblack16' } } })

p conf.get('settings.general.user')
# => "bblack16"

# You could also do this:
conf['settings.general.user']

# Recursively
conf.get('settings..user')
```
Note that :get will return the first matching value, but when using recursive paths it is possible to have multiple results. If you wish to see all matches use :get_all instead.

Additionally, you can retrieve values for root level keys by simply calling them on the configuration object.

```
conf = Harmoni.build('config.yml', default: { active: true })

puts conf.active
# => true
```

#### Set
You can also set values deeply using the set or [] method.
```
conf.set('my.nested.value', 99)

p conf.configuration
# => { my: { nested: { value: 99 } } }

# set also takes hashes
conf.set(active: true, count: 100)
```

### Synchronization

A config object does not have sync enabled upstream (from file) or downstream (to file) by default. There are several ways to enable this behavior:

```
conf = Harmoni.build('database.json')

# Turn on sync from file to memory
conf.sync_up = true

# Turn on sync from memory to file
conf.sync_down = true

# Or turn both up and down on at once
conf.sync = true

# Or specify sync options during instantiation
# NOTE: There is no need to combine :sync with :sync_up and/or :sync down,
# it is shown below for illustrative purposes only
conf = Harmoni.build('database.json', sync_up: true, sync: true, sync_down: true)
```

NOTE: Using Harmoni.sync() to create your config will automatically enable sync.

#### Sync Up

When sync up is enabled a file watcher thread is spun up within the instance of the config class. This thread will monitor the related file for changes and reload it and merge in changes whenever the mtime is changed. There are several behaviors you can tweak based on preference or use case. NOTE: All settings below can be passed to the :build, :sync or :new methods on instantiation.

- __interval__ [default: 1]: How often (in seconds) to check the file on disk for changes. The higher this is the more CPU it will require (especially when dealing with larger files).
- __prefer_memory__ [default: false]: When set to false changes on disk have precedence over changes in memory. That is to say, changes on disk are merged over top of configuration held in memory. When set to true the opposite occurs.
- __persist_memory__ [default: false]: When set to false any changes made in memory are overwritten or wiped out when reloading configuration from disk. When set to true changes are merged in to memory instead. This is useful when you want the file on disk to be the sole source-of-truth for your config.

#### Sync Down

When sync down is enabled any changes made using commands like :set or :[]= will force the configuration to save itself to disk. This keeps changes in memory in sync with those in the configuration file on disk.

### Event Hooks

There are currently two events that can be hooked. Details for each can be found in the following sub sections. Both hooks can be set by calling their respective setter or by passing them in as named arguments to :build, :sync or :new.

#### on_reload

on_reload can be passed a Proc or lambda to be executed any time the configuration is reloaded from disk. Reloads occur whenever the file's mtime is changed or if :reload is called manually. The configuration is passed in to the block as the only argument.


```
conf = Harmoni.sync('example.json', on_change: proc { |config| puts 'Config reloaded!'  })
```

#### on_change

on_change also takes a Proc or lambda but is called any time a reload is called that contains differences from the current configuration. Two arguments are passed to the block. The first is the full configuration, just like in on_reload but the second is a hash containing only the values that have changed (including nested changes). If a reload occurs that does not come with any changes, this hook will not be called.

```
conf = Harmoni.sync('test.yml', on_change: proc { |config, changes| puts "Got changes: #{changes}" })
```

### Defaults and Overlays

Harmoni also provides a mechanism to specify layers of configuration. You can specify a default configuration that the provided configuration (from disk or memory) will be merged over. This gives you an easy way to ensure certain keys exist and have a default value if they are not otherwise specified. You can also provide an overlay configuration that will be applied over the top of the configuration read in or set during run time. This allows you to prevent users from changing certain settings on disk or in memory.

The full precedence for merging each of the configs is as follows:

    default_configuration -> configuration -> overlay_configuration

Both :overlay_configuration and :default_configuration can be provided as named arguments on instantiation of via their respective setters. They are also aliased to the short methods :defaults and :overlay,

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/harmoni. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Harmoni project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/harmoni/blob/master/CODE_OF_CONDUCT.md).
