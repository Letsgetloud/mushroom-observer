# helpers for add Sequence view
module SequenceHelper
  # title for add_sequence page, e.g.:
	#   Add Sequence to Observation 123456
	#   Polyporus badius (Pers.) Schwein. (Consensus)
	#   Polyporus melanopus group (Observer Preference)
  def add_sequence_title(obs)
    capture do
      concat(:sequence_add_title.t)
      concat(" #{obs.id || "?"} ")
      concat(obs.name.format_name.t)
    end
  end

  def show_sequence_right_tabs(sequence)
  tabs = [
    link_with_query(:cancel_and_show.t(type: :observation),
                    @sequence.observation.show_link_args),
  ]
  retun tabs unless check_permission(@sequence)
  tabs.push(link_with_query(:EDIT.t, @sequence.edit_link_args)).
       push(link_with_query(:DESTROY.t, @sequence.destroy_link_args))
  end

  def sequence_accession_link(sequence)
    link_to(truncate(sequence.accession,
                               length: sequence.locus_width/2).t,
                      search_for_accession_url(sequence.archive,
                                               sequence.accession),
                      target: "_blank")
  end

  def sequence_archive_link(sequence)
    link_to(sequence.archive.t,
            archive(sequence.archive)[:home],
            target: "_blank")
  end

  # on-line primary-source repositories (Archives) for nucleotide sequences
  # in menu order
  #   name::    short name, used in drop-down menu
  #   home::    home page
  #   prefix::  prefix for Accession (When Accession is appended to this,
  #             it will land on the page for that Accession in the Archive.)
  def archives
    [
      { name:   "GenBank",
        home:   "https://www.ncbi.nlm.nih.gov/genbank/",
        prefix: "https://www.ncbi.nlm.nih.gov/nuccore/"},
      { name:   "ENA",
        home:   "http://www.ebi.ac.uk/ena",
        prefix: "http://www.ebi.ac.uk/ena/data/view/" },
      { name:   "UNITE",
        home:   "https://unite.ut.ee/",
        prefix: "https://unite.ut.ee/search.php?qresult=yes&accno="}
    ]
  end

  # returns the archive hash for the named archive
  def archive(name)
    archives.find {|r| r[:name] == name}
  end

  # url of a search for accession in the named external archive
  def search_for_accession_url(name, accession)
    archive(name)[:prefix] + accession
  end

  # dropdown list for add_sequence
  def archive_dropdown
    archives.each_with_object([]) do |archive, array|
      array << [archive[:name], archive[:name]]
    end
  end
end
