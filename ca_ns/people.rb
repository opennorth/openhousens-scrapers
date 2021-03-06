class NovaScotia
  def scrape_people
    party_ids = {}
    { 'Nova Scotia Liberal Party' => ['LIB'],
      'Nova Scotia New Democratic Party' => ['NDP'],
      'Progressive Conservative Association of Nova Scotia' => ['PC'],
      'Independent' => ['IND'],
    }.each do |name,abbreviations|
      organization = Pupa::Organization.new({
        name: name,
        classification: 'political party',
      })
      organization.add_source('http://electionsnovascotia.ca/candidates-and-parties/registered-parties', note: 'Elections Nova Scotia')
      abbreviations.each do |abbreviation|
        organization.add_name(abbreviation)
      end
      dispatch(organization)
      abbreviations.each do |abbreviation|
        party_ids[abbreviation] = organization._id
      end
    end

    legislature = Pupa::Organization.new({
      _id: 'ocd-organization/country:ca/province:ns/legislature',
      name: 'Nova Scotia House of Assembly',
      classification: 'legislature',
    })
    dispatch(legislature)

    # Darrell Dexter first appears in the debates as the Premier. However, we
    # don't want to create a person's whose name is "THE PREMIER".
    # @see http://nslegislature.ca/index.php/proceedings/hansard/C90/house_13may10/
    person = Pupa::Person.new({
      name: 'Darrell Dexter',
      family_name: 'Dexter',
      given_name: 'Darrell',
      sort_name: 'Dexter, Darrell',
    })
    create_person(person, 'http://nslegislature.ca/index.php/people/members/Darrell_Dexter')

    # John MacDonald doesn't really have a URL.
    person = Pupa::Person.new({
      name: 'John MacDonald',
      family_name: 'MacDonald',
      given_name: 'John',
      sort_name: 'MacDonald, John',
    })
    create_person(person, 'http://nslegislature.ca/index.php/people/members/john_macdonnell')

    get('http://nslegislature.ca/index.php/people/member-bios').css('#content tbody tr').each do |tr|
      next if tr.text[/\bVacant\b/]

      tds = tr.css('td')

      # Create the person.
      url = "http://nslegislature.ca#{tr.at_css('a')[:href]}"
      doc = get(url)
      script = doc.at_css('dd script')
      family_name, given_name = tds[0].text.split(', ', 2)

      person = Pupa::Person.new({
        name: "#{given_name} #{family_name}",
        family_name: family_name,
        given_name: given_name,
        sort_name: "#{family_name.sub(/\Ad'/, '')}, #{given_name}",
        image: doc.at_css('.portrait')[:src],
      })

      if script
        characters = script.text.scan(/'( \d+|..?)'/).flatten.reverse
        person.email = characters[characters.index('>') + 1..characters.rindex('<') - 1].map{|c| Integer(c).chr}.join
      end

      create_person(person, url)

      # Shared post and membership properties.
      area_name = tds[2].text
      shared_properties = {
        label: "MLA for #{area_name}",
        role: 'MLA',
        organization_id: legislature._id,
      }

      # Create the post.
      post = Pupa::Post.new(shared_properties.merge({
        area: {
          name: area_name,
        },
      }))
      post.add_source('http://nslegislature.ca/index.php/people/members/', note: 'Legislature MLA list')
      dispatch(post)

      # Create the post membership.
      membership = Pupa::Membership.new(shared_properties.merge({
        person_id: person._id,
        post_id: post._id,
      }))
      membership.add_source('http://nslegislature.ca/index.php/people/members/', note: 'Legislature MLA list')
      dispatch(membership)

      # Create the party membership.
      membership = Pupa::Membership.new({
        person_id: person._id,
        organization_id: party_ids.fetch(tds[1].text),
      })
      membership.add_source('http://nslegislature.ca/index.php/people/members/', note: 'Legislature MLA list')
      dispatch(membership)
    end
  end

private

  def create_person(person, url)
    person.add_source(url)
    dispatch(person)
    @speaker_ids[url] = person._id # XXX
  end
end
