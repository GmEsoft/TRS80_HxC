#include <stdio.h>
#include <io.h>
#include <ctype.h>
#include <stddef.h>
#include <string.h>

#include <fcntl.h>    // O_RDWR...
#include <sys/stat.h> // S_IWRITE

#define JV3_DISK "JV3 Disk Image Converter V0.3, (C) 2020-23 by GmEsoft"

typedef unsigned int uint32_t;

void help()
{
	puts(
		"JV3Disk -A|-C|-U|-X -I:infile [-O:outfile] [opts...]\n"
		"   -A          Analyze\n"
		"   -C          Create\n"
		"   -U          Update\n"
		"   -X          Extract\n"
		"   -I:infile   Input image file\n"								// infile
		"   -O:outfile  Output image file\n"							// outfile
		"opts:\n"
		"   -1          1st sector=1 (for  Create)\n"					// psector1
		"   -2          2-sided      (for  Create)\n"					// psides
		"   -T:nn       nn Tracks    (for  Create)  default 40\n"		// ptracks
		"               Start Track  (for Ext/Upd)  default  0\n"
		"   -S:nn       nn Sectors   (for  Create)  default 18\n"		// psectors
		"               Start Sector (for Ext/Upd)  default  0\n"
		"   -N:nn       nn Sectors   (for Ext/Upd)  default  0=all\n"	// pnsectors
		"   -V:nn       Sector Interleave (logical) default  1\n"		// pinterl
		"   -SS:nn      Sector Skew  (for  Create)  default  1\n"		// secskew
		"   -ST:nn      Track  Skew  (for  Create)  default  0\n"		// trkskew
		"   -SD:nn      Side   Skew  (for  Create)  default  0\n"		// sidskew
	);
}

#define SEC_LEN 256

/*******************************************************

				JV3 Disk format
				===============
00000-02200	Index of sectors (LSB_OFFSET,MSB_OFFSET,FLAGS)
			FLAGS: 1 - D S - - - -
				D = 1 for deleted sectors (DOS directory)
				S = side
02200-.....	Sectors data (256 bytes)

*******************************************************/

unsigned char buf[SEC_LEN];
unsigned char index[2901][3];
unsigned char interl[256];
unsigned char rinterl[256];
unsigned char secmap[256];
unsigned char rsecmap[256];

int trk=0, sec=0, sid=0, flags=0;
int cursid, curtrk;
int sector1=0x100, tracks=0, sectors=0, sides=0, dirtrk=-1;
int i;
int nbytes;
int psector1=0, psides=1, ptracks=0, psectors=0, pnsectors=0, pinterl=1;
int ptrkskew=0, psidskew=0, psecskew=1;

void make_secmap( int skew, unsigned char *map, unsigned char *rmap, int print )
{
	int secrev = sectors / skew;
	for ( i=0; i<sectors; ++i )
	{
		int j = ( i * skew ) % sectors + i / secrev;
		map[j] = i;
		rmap[i] = j;
	}

	if ( print ) for ( i=0; i<sectors; ++i )
	{
		printf( "%02d ", map[i] );
	}
}

void load_index( int infile )
{
	int secrev;

	printf( "Loading index ...\n" );
	lseek( infile, 0, SEEK_SET );
	for ( i=0; i<2901; ++i )
	{
		nbytes = read( infile, index[i], 3 );
		trk = index[i][0];
		if ( trk < 0xFF && trk >= tracks - 1 )
		{
			sec = index[i][1];
			flags = index[i][2];
			sid = ( flags & 0x10 ) >> 4;
			if ( trk >= tracks  ) tracks = trk + 1;
			if ( sec >= sectors ) sectors = sec + 1;
			if ( sec < sector1  ) sector1 = sec;
			if ( sid >= sides  ) sides = sid + 1;
			if ( flags & ~0x90 ) dirtrk = trk;
		}
	}
	sectors -= sector1;
	printf( "Disk image has %d side(s), %d tracks of %d sectors per side\n", sides, tracks, sectors );
	printf( "First sector is %d - DOS directory track is %d\n", sector1, dirtrk );

	printf( "Interleave table: " );
	make_secmap( pinterl, interl, rinterl, 1 );
	printf( "\n" );
}

void make_index( int outfile )
{
	printf( "Building index ...\n" );
	tracks = ptracks ? ptracks : 40;
	sides = psides;
	sectors = psectors ? psectors : 18;
	sector1 = psector1;

	// build sector skew map (physical--DOS)
	printf( "sector skew map : " );
	make_secmap( psecskew, secmap, rsecmap, 1 );
	printf( "\n" );

	// build sector interleave map (logical--cp/m)
	printf( "Interleave table: " );
	make_secmap( pinterl, interl, rinterl, 1 );
	printf( "\n" );

	lseek( outfile, 0, SEEK_SET );
	i = 0;
	for ( trk=0; trk<tracks; ++trk )
	{
		for ( sid=0; sid<sides; ++sid )
		{
			for ( sec=0; sec<sectors; ++sec, ++i )
			{
				index[i][0] = trk;
				index[i][1] = secmap[ ( ( sectors - ptrkskew ) * trk + sec ) % sectors ]+sector1;
				index[i][2] = 0x80 | ( sid * 0x10 );
				write( outfile, index[i], 3 );
			}
		}
	}

	for ( ; i<2901; ++i )
	{
		index[i][0] = index[i][1] = index[i][2] = 0xFF;
		write( outfile, index[i], 3 );
	}

	write( outfile, index[2900], 1 );
}

void analyze( int infile )
{
	int sec1 = -1, sidskew = -1, trkskew = -1, secskew = -1;

	load_index( infile );
	printf( "Interleave Pattern:" );
	cursid = -1;
	for ( i=0; i<8*sectors; ++i )
	{
		int phys_sec = i % sectors;
		trk = index[i][0];
		sec = index[i][1];
		flags = index[i][2];
		sid = ( flags & 0x10 ) >> 4;
		if ( cursid != sid || curtrk != trk )
		{
			cursid = sid;
			curtrk = trk;
			printf( "\nS%dT%02d: ", sid, trk );
		}
		printf( "%02d ", sec );

		if ( trk < 2 && sec < 3 )
		{
			int skew = ( sec1 - phys_sec + sectors ) % sectors;
			if ( sec == 1 )
			{
				if ( trk == 0 && sid == 1 )
					sidskew = skew;
				else if ( trk == 1 && sid == 0 )
					trkskew = skew;
				sec1 = phys_sec;
			}
			else if ( sec == 2 && trk == 0 && sid == 0 )
				secskew = sectors - skew;
		}
	}
	printf( "\n" );
	if ( secskew > 0 )
		printf( "Sector Skew : %d\n", secskew );
	if ( sidskew >= 0 )
		printf( "Side Skew   : %d\n", sidskew );
	if ( trkskew >= 0 )
		printf( "Track Skew  : %d\n", trkskew );
}

void extract( int infile, int outfile )
{
	int sector0;

	load_index( infile );

	sector0 = ( ptracks * sides * sectors + psectors );

	if ( psectors < sector1 )
		sector0 += sector1 - psectors;

	lseek( infile, 0x2200, SEEK_SET );

	curtrk = cursid = -1;

	for ( i=0; i<2901; ++i )
	{
		nbytes = read( infile, buf, SEC_LEN );

		if ( nbytes < SEC_LEN )
		{
			break;
		}

		trk = index[i][0];
		sec = interl[ index[i][1] - sector1 ] + sector1;
		flags = index[i][2];
		sid = ( flags & 0x10 ) >> 4;

		if ( trk < 0xFF )
		{
			int sector = ( trk * sides + sid ) * sectors + sec;
			if ( sector >= sector0 && ( !pnsectors || sector < sector0 + pnsectors ) )
			{
				if ( curtrk != trk || cursid != sid )
				{
					printf( "\nT:%02d S:%d sec", trk, sid );
					curtrk = trk;
					cursid = sid;
				}
				printf( ":%02d", sec );
				lseek( outfile, SEC_LEN * ( sector - sector0 ), SEEK_SET );
				write( outfile, buf, SEC_LEN );
			}
		}
	}
	printf( "\n" );

}

void create( int infile, int outfile, int update )
{
	int sector0, lastsector = -1;

	if ( update )
	{
		load_index( outfile );
	}
	else
	{
		make_index( outfile );
		ptracks = 0;
		psectors = 0;
	}

	sector0 = ( ptracks * sides * sectors + psectors );

	if ( psectors < sector1 )
		sector0 += sector1 - psectors;

	lseek( outfile, 0x2200, SEEK_SET );

	curtrk = cursid = -1;

	for ( i=0; i<2901; ++i )
	{
		trk = index[i][0];
		sec = interl[ index[i][1] - sector1 ] + sector1;
		flags = index[i][2];
		sid = ( flags & 0x10 ) >> 4;

		if ( trk < 127 )
		{
			int sector = ( trk * sides + sid ) * sectors + sec;
			if ( sector >= sector0 && ( !pnsectors || sector < sector0 + pnsectors ) )
			{
				if ( curtrk != trk || cursid != sid )
				{
					printf( "\nT:%02d S:%d sec", trk, sid );
					curtrk = trk;
					cursid = sid;
				}
				printf( ":%02d", sec );
				lseek( infile, SEC_LEN * ( sector - sector0 ), SEEK_SET );
				nbytes = read( infile, buf, SEC_LEN );
				if ( nbytes < SEC_LEN )
				{
					if ( update )
						printf( "*** Read error sector %d\n", sector - sector0 );
				}
				else if ( nbytes > 0 && lastsector < sector )
				{
					lastsector = sector;
				}

				while ( nbytes < SEC_LEN )
					buf[nbytes++] = 0x7D;

				lseek( outfile, 0x2200 + i * 0x100, SEEK_SET );
				nbytes = write( outfile, buf, SEC_LEN );

				if ( nbytes < SEC_LEN )
				{
					printf( "*** Write error T%02d:S%d:s%02d\n", trk, sid, sec );
					break;
				}
			}
		}
	}
	printf( "\n" );
	printf( "Last sector is %d\n", lastsector - sector0 );
}

int main( int argc, char* argv[] )
{
	int infile=0, outfile=0;

	int	i;

	char command = 'A';
	char sub = 0;

	puts( JV3_DISK "\n" );

	for ( i=1; i<argc; ++i )
	{
		char *s = argv[i];
		char c = 0;

		if ( *s == '-' )
			++s;
		switch ( toupper( *s ) )
		{
		case 'A': // Analyze
		case 'C': // Create
		case 'X': // eXtract
		case 'U': // Update
			command = toupper( *s );
			break;
		case 'I': // Input File
			++s;
			if ( *s == ':' )
				++s;
			printf( "Reading: %s\n", s );
			infile = open( s, _O_RDONLY | _O_BINARY, _S_IREAD );
			break;
		case 'O': // Output file
			++s;
			if ( *s == ':' )
				++s;
			if ( command == 'U' )
			{
				printf( "Updating: %s\n", s );
				outfile = open( s, _O_RDWR | _O_BINARY, _S_IWRITE );
			}
			else
			{
				printf( "Creating: %s\n", s );
				outfile = open( s, _O_CREAT | _O_TRUNC | _O_RDWR | _O_BINARY, _S_IWRITE );
			}
			break;
		case 'T': // Tracks(create), Start Track(update/extract)
			++s;
			if ( *s == ':' )
				++s;
			sscanf( s, "%d", &ptracks );
			break;
		case 'S': // Sectors(create), Start Sector(update/extract), Skew(create:Sec/Trk/Hd)
			++s;
			sub = toupper( *s );
			if ( sub == 'S' || sub == 'T' || sub == 'D' )
				++s;
			if ( *s == ':' )
				++s;
			switch ( sub )
			{
			case 'S': // Sector Skew (interleave)
				sscanf( s, "%d", &psecskew );
				break;
			case 'T': // Track Skew
				sscanf( s, "%d", &ptrkskew );
				break;
			case 'H': // Head Skew
			case 'D': // Side Skew
				sscanf( s, "%d", &psidskew );
				break;
			default:
				sscanf( s, "%d", &psectors );
			}
			break;
		case 'N': // Number of sectors to update/extract
			++s;
			if ( *s == ':' )
				++s;
			sscanf( s, "%d", &pnsectors );
			break;
		case 'V': // Logical Interleave Factor (Create/Update/Extract)
			++s;
			if ( *s == ':' )
				++s;
			sscanf( s, "%d", &pinterl );
			break;
		case '1': // First Sector is 1 (Create)
			psector1 = 1;
			break;
		case '2': // Double-Sided Diskette (Create)
			psides = 2;
			break;
		case '?': // Help
			help();
			return 0;
		default: // Undefined switch
			printf( "Unrecognized switch: -%s\n", s );
			printf( "JV3Disk -? for help.\n" );
			return 1;
		}

		if ( errno )
		{
			puts( strerror( errno ) );
			return 1;
		}
	}


	switch ( command )
	{
	case 'A': // Analyze
		analyze( infile );
		break;
	case 'C': // Create
		create( infile, outfile, 0 );
		break;
	case 'U': // Update
		create( infile, outfile, 1 );
		break;
	case 'X': // Extract
		extract( infile, outfile );
		break;
	}

	if ( infile )
		close( infile );

	if ( outfile )
		close( outfile );

	return 0;
}
