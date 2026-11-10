# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserService::ParseName do
  def parse(full_name)
    result = described_class.new(full_name:).run
    [result.first_name, result.last_name]
  end

  it "splits a simple name" do
    expect(parse("John Doe")).to eq(["John", "Doe"])
  end

  it "keeps middle names with the first name" do
    expect(parse("Donald Ervin Knuth")).to eq(["Donald Ervin", "Knuth"])
  end

  it "keeps particles with the last name" do
    expect(parse("Wernher von Braun")).to eq(["Wernher", "von Braun"])
    expect(parse("Juan de la Cruz")).to eq(["Juan", "de la Cruz"])
    expect(parse("Jean-Claude Van Damme")).to eq(["Jean-Claude", "Van Damme"])
  end

  it "keeps suffixes with the last name" do
    expect(parse("Martin Luther King Jr.")).to eq(["Martin Luther", "King Jr."])
  end

  it "understands the comma form" do
    expect(parse("Doe, John")).to eq(["John", "Doe"])
    expect(parse("Turing, Alan M.")).to eq(["Alan M.", "Turing"])
    expect(parse("Carreño Quiñones, María-Jose")).to eq(["María-Jose", "Carreño Quiñones"])
  end

  it "drops honorific titles" do
    expect(parse("Prof. Donald Ervin Knuth")).to eq(["Donald Ervin", "Knuth"])
    expect(parse("Sir Elton John")).to eq(["Elton", "John"])
  end

  it "puts a single name in first_name" do
    expect(parse("Madonna")).to eq(["Madonna", nil])
    expect(parse("O'Brien")).to eq(["O'Brien", nil])
  end

  # Namae reads leading lowercase words as particles and finds no given name.
  it "handles lowercase names" do
    expect(parse("ann marie")).to eq(["ann", "marie"])
    expect(parse("fiona rose hackworth")).to eq(["fiona rose", "hackworth"])
    expect(parse("john Smith")).to eq(["john", "Smith"])
  end

  it "normalizes whitespace" do
    expect(parse("  John   Doe  ")).to eq(["John", "Doe"])
  end

  it "returns nils for a blank name" do
    expect(parse(nil)).to eq([nil, nil])
    expect(parse("")).to eq([nil, nil])
    expect(parse("   ")).to eq([nil, nil])
  end

  # Namae has a list of honorifics (Elder, Lord, Pastor, Dr, ...) and gives up
  # or misparses when a surname collides with one. See hackclub/hcb#15467.
  describe "surnames that collide with Namae's title list" do
    it "falls back to a positional split when Namae returns nothing" do
      expect(parse("Jane Elder")).to eq(["Jane", "Elder"])
      expect(parse("Mary Lord")).to eq(["Mary", "Lord"])
      expect(parse("Peter Pastor")).to eq(["Peter", "Pastor"])
    end

    it "does not treat a trailing surname as a title" do
      expect(parse("Jane W Elder")).to eq(["Jane W", "Elder"])
      expect(parse("Ann Marie Count")).to eq(["Ann Marie", "Count"])
    end

    it "covers every word in the title list" do
      %w[Sir Lord Count Countess Gen Adm Col Maj Capt Cmdr Lt Sgt Cpl Pvt Pastor Pr Reverend Rev Elder Deacon
         Deaconess Father Fr Rabbi Cantor Vicar Prof Dr Md PhD].each do |surname|
        expect(parse("Jane #{surname}")).to eq(["Jane", surname]), "expected \"Jane #{surname}\" to split positionally"
      end
    end
  end
end
