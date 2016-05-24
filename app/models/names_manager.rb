# encoding: utf-8

require 'set'

module NamesManager
  PEOPLE_WHO_PREFER_THEIR_HANDLER_TO_BE_LISTED = %w(
    okkez
    maiha
    burningTyger
  )

  module EmailAddresses
    # I've sent an email to these email addresses, and there's no response
    # so far.
    WAITING_FOR = %W(
      agkr\100pobox.com
      alec+rails\100veryclever.net
      alex.r.moon\100gmail.com
      david.a.williams\100gmail.com
      dwlt\100dwlt.net
      edward.frederick\100revolution.com
      eli.gordon\100gmail.com
      eugenol\100gmail.com
      fhanshaw\100vesaria.com
      gaetanot\100comcast.net
      gnuman1\100gmail.com
      imbcmdth\100hotmail.com
      info\100loobmedia.com
      jan\100ulbrich-boerwang.de
      jhahn\100niveon.com
      jonrailsdev\100shumi.org
      junk\100miriamtech.com
      justin\100textdrive.com
      machomagna\100gmail.com
      me\100jonnii.com
      nick+rails\100ag.arizona.edu
      rails.20.clarry\100spamgourmet.com
      rails-bug\100owl.me.uk
      s.brink\100web.de
      schultzr\100gmail.com
      seattle\100rootimage.msu.edu
      yanowitz-rubyonrails\100quantumfoam.org
    )

    # I've sent an email to these addresses, and got some sort of error back.
    UNREACHABLE = %W(
      altano\100bigfoot.com
      asnem\100student.ethz.ch
      damn_pepe\100gmail.com
      dev.rubyonrails\100maxdunn.com
      kdole\100tamu.edu
      kevin-temp\100writesoon.com
      mklame\100atxeu.com
      nbpwie102\100sneakemail.com
      nkriege\100hotmail.com
      nwoods\100mail.com
      pfc.pille\100gmx.net
      rails\100cogentdude.com
      rcolli2\100tampabay.rr.com
      rubyonrails\100atyp.de
      solo\100gatelys.com
      starr\100starrnhorne.com
      zachary\100panandscan.com
    )

    ADDRESSES_WHOSE_CONTRIBUTORS_PREFER_TO_REMAIN_UNRESOLVED = %W(
      lagroue\100free.fr
    )
  end

  module GithubUsernames
    # I sent an internal message to these people asking for confirmation or full names.
    WAITING_FOR = %w(
      blackanger
      ian
      jerome
      mark
      Paul
      robby
      shane
      tom
      xavier
    )

    NOT_THEM = [
      'adam',
      'alex',
      'Andreas',
      'Caleb', # but wrote to Caleb Tennis, waiting for
      'dan',
      'David',
      'jamesh',
      'jonathan',
      'Kent',
      'mat',
      'Scott',
      'seth',
      'steve',
      'trevor'
    ]
  end

  # Returns a set with all (canonical) contributor names known by the application.
  def self.all_names
    Set.new(Contributor.connection.select_values("SELECT name FROM contributors"))
  end

  # Determines whether names mapping or special cases handling have been updated
  # since +ts+.
  def self.mapping_updated_since?(ts)
    File.mtime(__FILE__) > ts
  end

  # canonical name => handlers, emails, typos, etc.
  SEEN_ALSO_AS = {}
  def self.map(canonical_name, *also_as)
    SEEN_ALSO_AS[canonical_name.nfc] = also_as.map(&:nfc)
  end

  def self.authors_of_special_cased_commits(commit)
  end

  map "Sytse Sijbrandij",           "dosire"
  map "Dmitriy Zaporozhets",        "randx", "gitlabhq"
  map "Valeriy Sizov",              "Valery Sizov", "vsizov"
  map "Achilleas Pipinellis",       "axilleas", "Axilleas Pipinellis"
  map "Miks Miķelsons",             "miks"
  map "Connor Shea",                "connorshea"

  # Reverse SEEN_ALSO_AS to be able to go from handler to canonical name.
  CANONICAL_NAME_FOR = {}
  SEEN_ALSO_AS.each do |canonical_name, also_as|
    also_as.each { |alt| CANONICAL_NAME_FOR[alt] = canonical_name }
  end

  # Returns the canonical name for +name+.
  #
  # Email addresses are removed, leading/trailing whitespace is ignored. If no
  # equivalence is known the canonical name is the resulting sanitized string
  # by definition.
  def self.canonical_name_for(name)
    name = name.sub(/<[^>]+>/, '') # remove any email address in angles
    name.strip!
    CANONICAL_NAME_FOR[name] || name
  end

  # Removes email addresses (anything between <...>), and strips whitespace.
  def self.sanitize(name)
    name.sub(/<[^>]+>/, '').strip
  end

  CONNECTORS_REGEXP = %r{(?:[,/&+]|\band\b)}

  # Inspects raw candidates in search for rare cases.
  #
  # Returns +nil+ if +name+ is known *not* to correspond to an author, the
  # author name(s) if special handling applies, and return just +name+ back
  # otherwise.
  #
  # Note that this method is responsible for extracting names as they appear
  # in the original string. Canonicalization is done elsewhere.
  def self.handle_special_cases(name)
    case name
      when /\A#?\d+/
        # Remove side effects of [5684]
        # Ensure WhiteListSanitizer allows dl tag [#2393 state:resolved]
        nil
      when /\A\s*\z/
        nil
      when /^See rails ML/, /RAILS_ENV/
        nil
      when /RubyConf/
        # RubyConf '05
        nil
      when /\AIncludes duplicates of changes/
        # Includes duplicates of changes from 1.1.4 - 1.2.3
        nil
      when 'update from Trac'
        nil
      when /\A['":]/ # ' # this quote fixes JavaScript syntax highlighting
        # Instead of checking Rails.env.test? in Failsafe middleware, check env["rails.raise_exceptions"]
        # ... This lets ajax pages still use format.js despite there being no params[:format]
        nil
      when 'RC1'
        # Prepare for Rails 2.2.0 [RC1]
        nil
      when /\Astat(e|us):/
        # Fixed problem causes by leftover backup templates ending in tilde [state:committed #969]
        # Added ActionController::Translation module delegating to I18n #translate/#t and #localize/#l [status:committed #1008]
        nil
      when /\A#https/
        # Signed-off-by: Michael Koziarski <michael\100koziarski.com> [#https://rails.lighthouseapp.com/attachments/106066/0001-Ensure-SqlBypass-use-ActiveRecord-Base-connection.patch state:committed]
        nil
      when '\\x00-\\x1f'
        #  Fix ActiveSupport::JSON encoding of control characters [\x00-\x1f]
        nil
      when /\ACloses #\d+\z/i
        # Add shallow routes to the new router [Closes #3765]
        nil
      when /\AFixes #\d+\z/i
        # see https://github.com/rails/rails/commit/7db2ef47a1966113dd5d52c2f620b8496acabf56
        nil
      when /\ACVE-[\d-]+\z/i
        # fix protocol checking in sanitization [CVE-2013-1857]
        nil
      when 'and'
        # see https://github.com/rails/rails/commit/d891ad4e92c4f4d854ba321c42000026b5c75187
        nil
      when 'options'
        # see https://github.com/rails/rails/commit/bf176e9c7a1aa46b021384b91f4f9ec9a1132c0f
        nil
      when 'API DOCS'
        # see https://github.com/rails/rails/commit/9726ed8caf245c8702a781c9656f2b143a85f0f5
        nil
      when 'ed3796434af6069ced6a641293cf88eef3b284da'
        # see https://github.com/rails/rails/commit/509aa663601defc7c821c253d010605951e9d986
        nil
      when 'hat-tip to anathematic'
        # see https://github.com/rails/rails/commit/b67dc00eae310f61e02f1cae27ec78eb8c1c599b
        nil
      when 'props to Zarathu in #rubyonrails'
        # see https://github.com/rails/rails/commit/09b7e351316cb87a815678241fc90af549327cf3
        nil
      when 'thanks Pratik!'
        # see https://github.com/rails/rails/commit/a6467802ff2be35c6665635f1cdfdcea07aeaa12
        nil
      when 'type="month"'
        # see https://github.com/rails/rails/commit/b02d14aad515a039c284c93a68845503dc1658e2
        nil
      when 'multiple=true'
        # see https://github.com/rails/rails/commit/e591d14b9c4a1220dc55c93c01a81ad6219c1f2f
        nil
      when /ci[ _-]skip/i
        # see https://github.com/rails/rails/commit/86c5cea9f414d34fd92adb064fde5ecc7b40c727
        #     https://github.com/rails/rails/commit/86c5cea9f414d34fd92adb064fde5ecc7b40c727
        nil
      when /skip[ _-]ci/i
        # see https://github.com/rails/rails/commit/b1c28d710521c6931abc2b394de34ac8a174d844
        nil
      when 'ci ski'
        # see https://github.com/rails/rails/commit/1c2717d3f5a3ce0ea97f832d1d008e053ad47acd
        nil
      when 'AR:postgres'
        # see https://github.com/rails/rails/commit/d7b8f0c05945af83bb1ca446e23a26d8f99db2ca
        nil
      when 'for 3-2-stable'
        # see https://github.com/rails/rails/commit/b003ddf2aea1cec218604b62843faefef4b62a22
        nil
      when 'key'
        # see https://github.com/rails/rails/commit/98f4aee8dac22d9e9bb3c122b43e9e5ee8ba7d1c
        nil
      when /-> request/
        # see https://github.com/rails/rails/commit/fb9c00116bb7277f61a9d3ef5c399457f26056a4
        nil
      when /Bar::Engine/
        # see https://github.com/rails/rails/commit/0e69705b0fc7501bada74b3ca023ae7f7b2b8592
        nil
      when '#'
        # see https://github.com/rails/rails/commit/dd0040d19f2b161201fd54e21fc807fb987f016d
        nil
      when 'rounds #8213'
        # see https://github.com/rails/rails/commit/a8c3ea90f1490da4404aa1cea6fc6209f6b9b99b
        nil
      when 'Reopen/backport'
        # See https://github.com/rails/rails/commit/66e87b714b406a25af60156a1fa15d1ebb99a0bd
        nil
      when '.lock'
        # See https://github.com/rails/rails/commit/c71b9612c0dde4146bee86679e6319a913c24834
        nil
      when 'Constant3 Constant1'
        # See https://github.com/rails/rails/commit/3335cb7f12f059c8db8cc5195ef214d3215edf44
        nil
      when /\AFix for/
        # See https://github.com/rails/rails/commit/5d0d82957ae2658a576f5785506a52cfe03d0758
        nil
      when 'GET'
        # see https://github.com/rails/rails/commit/6871bd9818a9a7d9d8c7e21e253d64c0410fde1d
        nil
      when 'test/unit/bar_test.rb ...'
        # see https://github.com/rails/rails/commit/b4df25366a3c8f133f8329bc35f1d53926704b5a
        nil
      when 'Carlhuda'
        ['Yehuda Katz', 'Carl Lerche']
      when 'tomhuda'
        ['Yehuda Katz', 'Tom Dale']
      when "schoenm\100earthlink.net sandra.metz\100duke.edu"
        name.split
      when '=?utf-8?q?Adam=20Cig=C3=A1nek?='
        'Adam Cigánek'.nfc
      when '=?utf-8?q?Mislav=20Marohni=C4=87?='
        'Mislav Marohnić'.nfc
      when 'Thanks to Austin Ziegler for Transaction::Simple'
        'Austin Ziegler'
      when 'nik.wakelin Koz'
        ['nik.wakelin', 'Koz']
      when "me\100jonnii.com rails\100jeffcole.net Marcel Molina Jr."
        ["me\100jonnii.com", "rails\100jeffcole.net", 'Marcel Molina Jr.']
      when "jeremy\100planetargon.com Marcel Molina Jr."
        ["jeremy\100planetargon.com", 'Marcel Molina Jr.']
      when "matt\100mattmargolis.net Marcel Molina Jr."
        ["matt\100mattmargolis.net", 'Marcel Molina Jr.']
      when "doppler\100gmail.com phil.ross\100gmail.com"
        ["doppler\100gmail.com", "phil.ross\100gmail.com"]
      when 'After much pestering from Dave Thomas'
        'Dave Thomas'
      when 'Aredridel/earlier work by Michael Neumann'
        ['Aredridel', 'Michael Neumann']
      when "jon\100blankpad.net)"
        # see 35d3ede
        ["jon\100blankpad.net"]
      when 'Jose and Yehuda'
        ['José Valim', 'Yehuda Katz'].map(&:nfc)
      when /\b\w+\+\w+@/
        # The plus sign is taken to be a connector below, this catches some known
        # addresses that use a plus sign in the username, see unit tests for examples.
        # We know there's no case where the plus sign acts as well as a connector in
        # the same string.
        name.split(/\s*,\s*/).map(&:strip)
      when /\A(Spotted|Suggested|Investigation|earlier work|Aggregated)\s+by\s+(.*)/i
        # Spotted by Kevin Bullock
        # Suggested by Carl Youngblood
        # Investigation by Scott
        # earlier work by Michael Neumann
        # Aggregated by schoenm ~ at ~ earthlink.net
        $2
      when /\A(?:DHH\s*)?via\s+(.*)/i
        # DHH via Jay Fields
        # via Tim Bray
        $1
      when CONNECTORS_REGEXP # There are lots of these, even with a combination of connectors.
        # [Adam Milligan, Pratik]
        # [Rick Olson/Nicholas Seckar]
        # [Kevin Clark & Jeremy Hopple]
        # Yehuda Katz + Carl Lerche
        # Nick Quaranto and Josh Nichols
        name.split(CONNECTORS_REGEXP).map(&:strip).reject do |part|
          part == 'others' || # foamdino ~ at ~ gmail.com/others
          part == '?'         # Sam Stephenson/?
        end
      else
        # just return the candidate back
        name
    end
  end
end

#
# Some facts:
#   * the handler "todd" is not Todd Hanson
#
