use XML::LibXML;
use XML::LibXML::Reader;
use File::Monitor;
use File::Copy;
use FileHandle;
use strict;
use Data::GUID;

#  Add Unique Identifier to filename for automated testing, downloading xml overwrites the xml file.
my $Id;

my $FH;
my $cnt;
my $FileName;
my $InputFile;
my $KeepFileFlag;
my $FH1         = FileHandle->new;
my $FH2         = FileHandle->new;
my $FHCreateVIN = FileHandle->new;
my $FilePath;
my $PlatformDir;
my $IniFile = "//ATC-FS01/Master/DriveWorks Project/Projects/System Files/HendrixXMLToAutoPilot.ini";
my $HendrixXMLInputDir;
my $HendrixXMLArchiveDir;

my $MasterFilePath;
my $SleepTimerSec = 5;
my $Monitor       = File::Monitor->new();
my $Number;
my $DateTime;
my $VIN = "";
my $VIN6;

GetValuesFromFile();

$Monitor->watch( { name => $HendrixXMLInputDir, recurse => 0 } );
while (1) {
  $DateTime = GetDateTime();
  print $DateTime . "\n";

  for my $change ( $Monitor->scan ) {
	$Id = Data::GUID->new->as_string;

	#print $change->name, " changed\n";
	opendir( DIR, $HendrixXMLInputDir ) or die "Couldn't open directory: $HendrixXMLInputDir, $!";
	while ( my $FileName = readdir DIR ) {
	  if ( ( $FileName =~ ".xml" ) && ( $FileName =~ /^\d+/ ) ) {
		$FH        = FileHandle->new;
		$InputFile = "$HendrixXMLInputDir/$FileName";

		$KeepFileFlag = FindChildElements();
		close($FH);
		if ( !$KeepFileFlag ) { unlink "$FilePath/$PlatformDir/Autopilot Queue/$VIN6 - $Id.xml"; }
    my $FilenameArch = substr($Filename, 0, 6) . '.xml';
		move "$HendrixXMLInputDir/$FileName", "$HendrixXMLArchiveDir/$FileNameArch" or die "The move operation failed: $!";
	  }
	}
	closedir DIR;
  }
  sleep $SleepTimerSec;
}

sub FindChildElements {

  my $FileNameOnly = $FileName;
  $FileNameOnly =~ s/.xml//;

  my $Name;
  my $Value;
  my $VIN;
  my $VIN3 = substr $FileNameOnly, 0, 3;
  my $VIN3Dir;
  $VIN6 = substr $FileNameOnly, 0, 6;
  my $VIN6Dir;
  my $Customer = "Stock";
  my $DirPath;
  my $Platform;
  my $Project;
  my $VIN6DirExists = 0;

  $KeepFileFlag = 0;

  my $doc = XML::LibXML::Document->new('1.0');

  my $reader = XML::LibXML::Reader->new( location => $InputFile ) or die "cannot read $InputFile: $!\n";

  while ( $reader->read ) {
	if ( ( $reader->nodeType == 1 ) && ( $reader->name eq "Customer" ) ) {
	  if ( $reader->getAttribute("name") ) {
		$Customer = $reader->getAttribute("name");
		$Customer =~ s/&/and/g;
	  }
	}
	if ( ( $reader->nodeType == 1 ) && ( $reader->name eq "ConfigItem" ) ) {
	  if ( $reader->getAttribute("name") eq "ModelNumberConfigured" ) {
		$Platform = substr $reader->getAttribute("value"), 0, 3;
		if ( $Platform eq "ARV" ) {
		  $Project     = "ARV";
		  $PlatformDir = "ARV";
		}
		elsif ( $Platform eq "QST" ) {
		  $Project     = "QST REL";
		  $PlatformDir = "QST_LIMITED";
		}
	  }
	}
  }
print "$FilePath/$PlatformDir/Autopilot Queue/\n";
  $FH->open("> $FilePath/$PlatformDir/Autopilot Queue/$VIN6 - $Id.xml") or die "Failed to Create File: $VIN6 - $Id.xml, $!";

  # Specifications
  my $Specifications = $doc->createElement('Specifications');
  $Specifications->addChild( $doc->createAttribute( "xmlns" => "http://schemas.driveworks.co.uk/interop/specification/1/0" ) );

  # Specification
  my $Specification = $doc->createElement('Specification');
  $Specification->addChild( $doc->createAttribute( "Project"    => $Project ) );
  $Specification->addChild( $doc->createAttribute( "Transition" => "Release" ) );

  $Specifications->addChild($Specification);

  if ( $VIN6 eq "" ) {
	( $VIN, $DirPath ) = GetVIN($IniFile);
	$Value = $VIN;
  }
  else {
	$Value = $VIN6;
	print "$MasterFilePath\n";
	opendir( DIR, $MasterFilePath ) or die "Couldn't open directory, $!";
	while ( $VIN3Dir = readdir DIR ) {
	  if ( $VIN3Dir =~ $VIN3 ) {
		opendir( DIR, $MasterFilePath . "/" . $VIN3Dir ) or die "Couldn't open directory, $!";
		while ( $VIN6Dir = readdir DIR ) {
		  if ( $VIN6Dir =~ $VIN6 ) {
			$VIN6DirExists = 1;
			print "$VIN6Dir\n";
			if   ( $VIN6Dir eq $FileNameOnly ) { }
			else                               { $FileNameOnly = $VIN6Dir; }
		  }
		}
	  }
	}
	if ( $VIN6DirExists eq 0 ) {
	  my $CreateVINFile = $FileNameOnly;
	  $CreateVINFile =~ s/ - /~~/;
	  $CreateVINFile =~ s/ - /~~/;
	  print "$CreateVINFile\n";

	  $FHCreateVIN->open("> $MasterFilePath/FolderQueue/$CreateVINFile") or die "Unable to create file, $!";
	  $FHCreateVIN->close;
	  sleep 10;
	}
  }
  my $Input = $doc->createElement('Input');
  $Specification->addChild($Input);
  $Input->addChild( $doc->createAttribute( "Name" => "VIN" ) );
  $Input->appendText($Value);

  $reader = XML::LibXML::Reader->new( location => $InputFile ) or die "cannot read $InputFile\n";

  my $VINDateTimeDir = "$MasterFilePath/$VIN3 VINS/$FileNameOnly/Engineering/$DateTime";
  $VINDateTimeDir =~ s/\//\\/g;
  print "$VINDateTimeDir\n";

  while ( $reader->read ) {
	if ( ( $reader->nodeType == 1 ) && ( $reader->name eq "ConfigItem" ) ) {
	  if ( $reader->getAttribute("name") =~ "DW_" ) {
		$KeepFileFlag = 1;
		$Name         = $reader->getAttribute("name");
		$Name =~ s/DW_//;

		# Input

		#if    ( $Name =~ "VIN" )       { $Value = $VIN6; }
		if    ( $Name =~ "Directory" )    { $Value = $VINDateTimeDir; }
		elsif ( $Name =~ "CustomerName" ) { $Value = $Customer; }
		elsif ( $Name =~ "DrawnBy" )      { $Value = "DW"; }
		else                              { $Value = $reader->getAttribute("value"); }
		if ( $Name !~ "VIN" ) {
		  my $Input = $doc->createElement('Input');
		  $Specification->addChild($Input);
		  $Input->addChild( $doc->createAttribute( "Name" => $Name ) );
		  $Input->appendText($Value);
		  $doc->setDocumentElement($Specifications);
		}
	  }
	}
  }
  if ( !-d $VINDateTimeDir ) {
	mkdir $VINDateTimeDir or die "Unable to create $VINDateTimeDir\n";
  }

  copy "$HendrixXMLInputDir/$FileName", $VINDateTimeDir or die "Unable to copy $HendrixXMLInputDir/$FileName, $!\n";

  my $xml_document = $doc->toString();    # returns a byte string
  print $FH sprintf "%s", ($xml_document);
  return ($KeepFileFlag);
}

sub GetValuesFromFile {

  #  $IniFile = shift;
  my @OutputFileArray;
  my @TempVar;
  my $HendrixDir;
  my $DirPath;

  $FH1->open("< $IniFile") or die "Failed to Open File: $IniFile, $!";
  $cnt = 0;
  while ( $_ = <$FH1> ) {
	chomp $_;
	$OutputFileArray[$cnt] = $_;
	@TempVar = split( "::", $_ );
	if ( $TempVar[0] eq "VIN" ) {
	  $TempVar[1]++;
	  $VIN = $TempVar[1];
	  $OutputFileArray[$cnt] = $TempVar[0] . "::" . $TempVar[1];
	}
	elsif ( $TempVar[0] eq "FilePath" ) {
	  $FilePath = $TempVar[1];
	}
	elsif ( $TempVar[0] eq "HendrixDir" ) {
	  $HendrixDir = "$FilePath/$TempVar[1]";
	}
	elsif ( $TempVar[0] eq "HendrixXMLInputDir" ) {
	  $HendrixXMLInputDir = "$FilePath/$TempVar[1]";
	}
	elsif ( $TempVar[0] eq "HendrixXMLArchiveDir" ) {
	  $HendrixXMLArchiveDir = "$FilePath/$TempVar[1]";
	}
	elsif ( $TempVar[0] eq "MasterFilePath" ) {
	  $MasterFilePath = "$TempVar[1]";
	}

	$cnt++;
  }
  close($FH1);

  $FH2 = FileHandle->new;
  $FH2->open("> $IniFile") or die "Failed to Create File: $IniFile, $!";
  $cnt = 0;
  foreach (@OutputFileArray) { print $FH2 sprintf "%s\n", ("$OutputFileArray[$cnt]"); $cnt++; }
  close($FH2);
  $DirPath = "$HendrixDir/$VIN";
  mkdir $DirPath;

    # *** Print File Paths ***
  print "Hendrix Dir: $HendrixDir\n";
  print "Hendrix XML Dir: $HendrixXMLInputDir\n";
  print "MasterFile Dir: $MasterFilePath\n";

  $DirPath =~ s/\//\\/g;
  return ( $VIN, $DirPath );
}

sub GetDateTime {
  ( my $sec, my $min, my $hour, my $mday, my $mon, my $year ) = localtime(time);
  $sec  = sprintf "%02d", $sec;
  $min  = sprintf "%02d", $min;
  $hour = sprintf "%02d", $hour;
  $mday = sprintf "%02d", $mday;
  $mon  = sprintf "%02d", $mon += 1;
  $year = substr( $year + 1900, 0 );
  return "$year$mon$mday\_$hour$min$sec";
}
