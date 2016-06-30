include AutomationSpecHelper
module MiqAeBrowserSpec
  include MiqAeEngine
  describe MiqAeBrowser do
    before(:each) do
      MiqAeDatastore.reset
      @composition_fields = {"title" => {:aetype => "attribute", :datatype => "string"}}

      @chopin_domain = {:name => "Chopin", :ae_namespace => "SelectedWorks", :ae_class => "Piano"}
      @chopin_piano_compositions = {"Nocturnes" => {"title"    => {:value => "18 Noctures"}},
                                    "Ballades"  => {"title" => {:value => "4 Ballades"}},
                                    "Scherzos"  => {"title" => {:value => "4 Scherzos"}}}

      @liszt_domain = {:name => "Liszt", :ae_namespace => "SelectedWorks", :ae_class => "Piano"}
      @liszt_piano_compositions = {"Rhapsodies" => {"title" => {:value => "19 Hungarian Rhapsodies"}},
                                   "Etudes"     => {"title" => {:value => "12 Transcendental Etudes"}}}

      create_ae_model(@chopin_domain.merge(:ae_fields    => @composition_fields,
                                           :ae_instances => @chopin_piano_compositions))

      create_ae_model(@liszt_domain.merge(:ae_fields    => @composition_fields,
                                          :ae_instances => @liszt_piano_compositions))
      @state_machine_fqnames = %w(
        /Liszt
        /Liszt/SelectedWorks
        /Liszt/SelectedWorks/Learning
        /Liszt/SelectedWorks/Learning/Campanella
      )

      learning_fields = {"study"   => {:aetype => "state", :datatype => "string"},
                         "perform" => {:aetype => "state", :datatype => "string"}}

      learning_instances = {"Campanella" => {"study"   => {:value => "inprogress"},
                                             "perform" => {:value => ""}}}

      FactoryGirl.create(:miq_ae_class, :with_instances_and_methods,
                         :name => "Learning", :namespace => "/Liszt/SelectedWorks",
                         :ae_fields => learning_fields, :ae_methods => {}, :ae_instances => learning_instances)

      @user = FactoryGirl.create(:user_with_group)
      @browser = MiqAeBrowser.new(@user)
    end

    it "can query root base object" do
      res = @browser.search("/", :scope => "base")
      expect(res.size).to eq(0)
    end

    it "can query root domains" do
      res = @browser.search(nil, :scope => "one")
      expect(res.pluck(:name)).to match_array(%w(Chopin Liszt))
    end

    it "can query a domain base object" do
      res = @browser.search("/Chopin", :scope => "base")
      expect(res.first).to eq(MiqAeDomain.where(:name => "Chopin").first)
    end

    it "defaults to scope sub search" do
      res = @browser.search("/Chopin")
      expect(res.pluck(:name)).to match_array(%w(Chopin SelectedWorks Piano Nocturnes Ballades Scherzos))
    end

    it "supports scope sub search" do
      res = @browser.search("/Liszt", :scope => "sub")
      expect(res.pluck(:name)).to match_array(%w(Liszt SelectedWorks Piano Rhapsodies Etudes Learning Campanella))
    end

    it "scope sub search on root gets all objects" do
      res = @browser.search("/", :scope => "sub")
      all_nodes = %w(Chopin SelectedWorks Piano Nocturnes Ballades Scherzos
                     Liszt SelectedWorks Piano Rhapsodies Etudes Learning Campanella)
      expect(res.pluck(:name)).to match_array(all_nodes)
    end

    it "supports serialized output" do
      res = @browser.search("/Liszt/SelectedWorks/Piano/Etudes", :scope => "base", :serialize => true)
      expect(res.size).to eq(1)
      expect(res.first).to be_kind_of(Hash)
      expect(res.first).to include("fqname"        => "/Liszt/SelectedWorks/Piano/Etudes",
                                   "domain_fqname" => "/SelectedWorks/Piano/Etudes",
                                   "klass"         => "MiqAeInstance")
    end

    it "supports serialized output with scope one" do
      res = @browser.search("/Chopin/SelectedWorks/Piano", :scope => "one", :serialize => true)
      expected_chopin_piano_works = %w(
        /Chopin/SelectedWorks/Piano
        /Chopin/SelectedWorks/Piano/Nocturnes
        /Chopin/SelectedWorks/Piano/Ballades
        /Chopin/SelectedWorks/Piano/Scherzos
      )
      expect(res.collect { |h| h["fqname"] }).to match_array(expected_chopin_piano_works)
    end

    it "support query of state_machine tree" do
      res = @browser.search("/", :scope => "sub", :state_machines => true)
      expect(res.collect(&:fqname)).to match_array(@state_machine_fqnames)
    end

    it "support serialized query of state_machine tree" do
      res = @browser.search("/", :scope => "sub", :state_machines => true, :serialize => true)
      expect(res.collect { |h| h["fqname"] }).to match_array(@state_machine_fqnames)
    end
  end
end
