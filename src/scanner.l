/* $Id: scanner.l,v 1.1 2000-09-12 00:12:52 rjkaes Exp $
 *
 * This builds the scanner for the tinyproxy configuration file. This
 * file needs to stay in sync with grammar.y. If someone knows lex and yacc
 * better than I do, please update these files.
 *
 * Copyright (C) 2000  Robert James Kaes (rjkaes@flarenet.com)
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2, or (at your option) any
 * later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 */
%{

#include "tinyproxy.h"
#include "grammar.h"
#include <string.h>
#include <stdio.h>

struct keyword {
        char *kw_name;
        int kw_token;
};

static struct keyword keywords[] = {
        /* statements */
        { "port",		 KW_PORT },
	{ "logfile",		 KW_LOGFILE },
	{ "syslog",		 KW_SYSLOG },
	{ "maxclients",		 KW_MAXCLIENTS },
	{ "maxspareservers",	 KW_MAXSPARESERVERS },
	{ "minspareservers",	 KW_MINSPARESERVERS },
	{ "startservers",	 KW_STARTSERVERS },
	{ "maxrequestsperchild", KW_MAXREQUESTSPERCHILD },
	{ "pidfile",		 KW_PIDFILE },
	{ "timeout",		 KW_TIMEOUT },
	{ "listen",		 KW_LISTEN },
	{ "user",		 KW_USER },
	{ "group",		 KW_GROUP },
	{ "anonymous",		 KW_ANONYMOUS },
	{ "filter",		 KW_FILTER },
	{ "xtinyproxy",		 KW_XTINYPROXY },
	{ "tunnel",		 KW_TUNNEL },
	{ "allow",		 KW_ALLOW },
        { "deny",                KW_DENY },

	/* on/off switches */
	{ "yes",		 KW_YES },
	{ "on",			 KW_YES },
	{ "no",			 KW_NO },
	{ "off",		 KW_NO }
	
}; 

#define YY_NO_UNPUT 1

#define MAX_REGEXP_LEN	1024

unsigned int yylineno = 1;
char tiny_buf[MAX_REGEXP_LEN];
char *tiny_str;

static int check_reserved_words(char *token);
static void append_string(int length, char *str);
static void append_char(char c);
%}

%option noyywrap

white		[ \t]
digit		[0-9]
alpha		[a-zA-Z]
alphanum	[a-zA-Z0-9]
word		[^ \#'"\(\)\{\}\\;\n\t,|\.]

%x string

%%

\#.*$		        ;
\n                      { yylineno++; return '\n'; }
{white}+                ;
0x{digit}+              { yylval.num = strtol(yytext, NULL, 16); return NUMBER; }
0{digit}+               { yylval.num = strtol(yytext, NULL, 8); return NUMBER; }
{digit}+                { yylval.num = atoi(yytext); return NUMBER; }
{alpha}+	        { return check_reserved_words(yytext); }
':'			{ return ':'; }
'/'			{ return '/'; }
\"			{
			        tiny_str = tiny_buf;
				BEGIN(string);
			}
<string>\\a		{ append_char(7); }
<string>\\n		{ append_char(10); }
<string>\\r		{ append_char(13); }
<string>\\t		{ append_char(9); }
<string>\\v		{ append_char(11); }
<string>\\[^anrtv]	{ append_string(1, yytext + 1); }
<string>\"		{
				BEGIN(INITIAL);
				yylval.cptr = strdup(tiny_buf);
				return STRING;
			}
<string>[^"\\]+		{ append_string(strlen(yytext), yytext); }


({digit}{1,3}\.){3}{digit}{1,3} { yylval.cptr = strdup(yytext); return NUMERIC_ADDRESS; }
({digit}{1,3}\.){3}{digit}{1,3}\/{digit}+ { yylval.cptr = strdup(yytext); return NETMASK_ADDRESS; }
([-_a-z0-9]+\.)+[a-z]+		{ yylval.cptr = strdup(yytext); return STRING_ADDRESS; }


%%

int check_reserved_words(char *token)
{
	int i;

	for (i = 0; i < (sizeof(keywords) / sizeof(struct keyword)); i++) {
	        if (strcasecmp(keywords[i].kw_name, token) == 0) {
		        return keywords[i].kw_token;
		}
	}
	yylval.cptr = strdup(token);
	return IDENTIFIER;
}

static void append_string(int length, char *s)
{
	int to_copy = min(MAX_REGEXP_LEN - (tiny_str - tiny_buf) - 1, length);

	memcpy(tiny_str, s, to_copy);
	tiny_str += to_copy;
	*tiny_str = 0;
}

static void append_char(char c)
{
	*tiny_str = c;
	tiny_str++;
	*tiny_str = 0;
}