#ifndef IPUTILS_PING_H
#define IPUTILS_PING_H

/* Includes */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>
#include <signal.h>
#include <poll.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <linux/types.h>
#include <linux/sockios.h>
#include <sys/file.h>
#include <sys/time.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <sys/uio.h>
#include <ctype.h>
#include <errno.h>
#include <string.h>
#include <netdb.h>
#include <setjmp.h>
#include <netinet/icmp6.h>
#include <asm/byteorder.h>
#include <sched.h>
#include <math.h>
#include <netinet/ip.h>
#include <netinet/ip6.h>
#include <netinet/ip_icmp.h>
#include <netinet/icmp6.h>
#include <linux/filter.h>
#include <resolv.h>

#ifdef HAVE_LIBCAP
# include <sys/prctl.h>
# include <sys/capability.h>
#endif

#include "iputils_common.h"
#include "iputils_ni.h"

#ifdef USE_IDN
# define getaddrinfo_flags (AI_CANONNAME | AI_IDN | AI_CANONIDN)
# define getnameinfo_flags NI_IDN
#else
# define getaddrinfo_flags (AI_CANONNAME)
# define getnameinfo_flags 0
#endif

#include <ifaddrs.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <linux/types.h>
#include <linux/errqueue.h>
#include <linux/in6.h>
/* All includes done. */

#ifndef SCOPE_DELIMITER
# define SCOPE_DELIMITER '%'
#endif

#define	DEFDATALEN	(64 - 8)	/* default data length */

#define	MAXWAIT		10		/* max seconds to wait for response */
#define MININTERVAL	10		/* Minimal interpacket gap */
#define MINUSERINTERVAL	200		/* Minimal allowed interval for non-root */

#define SCHINT(a)	(((a) <= MININTERVAL) ? MININTERVAL : (a))


#ifndef MSG_CONFIRM
#define MSG_CONFIRM 0
#endif

/*
 * MAX_DUP_CHK is the number of bits in received table, i.e. the maximum
 * number of received sequence numbers we can keep track of.
 */
#define	MAX_DUP_CHK	0x10000

#if defined(__WORDSIZE) && __WORDSIZE == 64
# define USE_BITMAP64
#endif

#ifdef USE_BITMAP64
typedef uint64_t	bitmap_t;
# define BITMAP_SHIFT	6
#else
typedef uint32_t	bitmap_t;
# define BITMAP_SHIFT	5
#endif

#if ((MAX_DUP_CHK >> (BITMAP_SHIFT + 3)) << (BITMAP_SHIFT + 3)) != MAX_DUP_CHK
# error Please MAX_DUP_CHK and/or BITMAP_SHIFT
#endif

struct rcvd_table {
	bitmap_t bitmap[MAX_DUP_CHK / (sizeof(bitmap_t) * 8)];
};

typedef struct socket_st {
	int fd;
	int socktype;
} socket_st;

struct ping_rts;

int ping4_run(struct ping_rts *rts, int argc, char **argv, struct addrinfo *ai, socket_st *sock);
int ping4_send_probe(struct ping_rts *rts, socket_st *, void *packet, unsigned packet_size);
int ping4_receive_error_msg(struct ping_rts *, socket_st *);
int ping4_parse_reply(struct ping_rts *, socket_st *, struct msghdr *msg, int len, void *addr, struct timeval *);
void ping4_install_filter(struct ping_rts *rts, socket_st *);

typedef struct ping_func_set_st {
	int (*send_probe)(struct ping_rts *rts, socket_st *, void *packet, unsigned packet_size);
	int (*receive_error_msg)(struct ping_rts *rts, socket_st *sock);
	int (*parse_reply)(struct ping_rts *rts, socket_st *, struct msghdr *msg, int len, void *addr, struct timeval *);
	void (*install_filter)(struct ping_rts *rts, socket_st *);
} ping_func_set_st;

/* Node Information query */
struct ping_ni {
	int query;
	int flag;
	void *subject;
	int subject_len;
	int subject_type;
	char *group;
#if PING6_NONCE_MEMORY
	uint8_t *nonce_ptr;
#else
	struct {
		struct timeval tv;
		pid_t pid;
	} nonce_secret;
#endif
};

/*ping runtime state */
struct ping_rts {
	int mark;
	unsigned char *outpack;

	struct rcvd_table *rcvd_tbl;

	size_t datalen;
	char *hostname;
	uid_t uid;
	uid_t euid;
	int ident;			/* random id to identify our packets */
	int sndbuf;
	int ttl;

	long npackets;			/* max packets to transmit */
	long nreceived;			/* # of packets we got back */
	long nrepeats;			/* number of duplicates */
	long ntransmitted;		/* sequence # for outbound packets = #sent */
	long nchecksum;			/* replies with bad checksum */
	long nerrors;			/* icmp errors */
	int interval;			/* interval between packets (msec) */
	int preload;
	int deadline;			/* time to die */
	int lingertime;
	struct timeval start_time, cur_time;
	volatile int exiting;
	volatile int status_snapshot;
	int confirm;
	int confirm_flag;
	char *device;
	int pmtudisc;

	volatile int in_pr_addr;	/* pr_addr() is executing */
	jmp_buf pr_addr_jmp;

	/* timing */
	int timing;			/* flag to do timing */
	long tmin;			/* minimum round trip time */
	long tmax;			/* maximum round trip time */
	double tsum;			/* sum of all times, for doing average */
	double tsum2;
	int rtt;
	int rtt_addend;
	uint16_t acked;
	int pipesize;

	ping_func_set_st ping4_func_set;
	ping_func_set_st ping6_func_set;
	uint32_t tclass;
	uint32_t flowlabel;
	struct sockaddr_in6 source6;
	struct sockaddr_in6 whereto6;
	struct sockaddr_in6 firsthop6;

	/* Used only in ping.c */
	int ts_type;
	int nroute;
	uint32_t route[10];
	struct sockaddr_in whereto;	/* who to ping */
	int optlen;
	int settos;			/* Set TOS, Precedence or other QOS options */
	int broadcast_pings;
	int multicast;
	struct sockaddr_in source;

	/* Used only in ping_common.c */
	int screen_width;
#ifdef HAVE_LIBCAP
	cap_value_t cap_raw;
	cap_value_t cap_admin;
#endif

	/* Used only in ping6_common.c */
	struct sockaddr_in6 firsthop;
	unsigned char *cmsgbuf;
	size_t cmsglen;
	struct ping_ni ni;

	/* boolean option bits */
	unsigned int
		opt_adaptive:1,
		opt_audible:1,
		opt_flood:1,
		opt_flood_poll:1,
		opt_flowinfo:1,
		opt_interval:1,
		opt_latency:1,
		opt_mark:1,
		opt_noloop:1,
		opt_numeric:1,
		opt_outstanding:1,
		opt_pingfilled:1,
		opt_ptimeofday:1,
		opt_quiet:1,
		opt_rroute:1,
		opt_so_debug:1,
		opt_so_dontroute:1,
		opt_sourceroute:1,
		opt_strictsource:1,
		opt_tclass:1,
		opt_timestamp:1,
		opt_ttl:1,
		opt_verbose:1;
};
/* FIXME: global_rts will be removed in future */
extern struct ping_rts *global_rts;

#define	A(bit)	(rts->rcvd_tbl->bitmap[(bit) >> BITMAP_SHIFT])	/* identify word in array */
#define	B(bit)	(((bitmap_t)1) << ((bit) & ((1 << BITMAP_SHIFT) - 1)))	/* identify bit in word */

void rcvd_clear(struct ping_rts *rts, uint16_t seq);
bitmap_t rcvd_test(struct ping_rts *rts, uint16_t seq);
void write_stdout(const char *str, size_t len);
void acknowledge(struct ping_rts *rts, uint16_t seq);

extern void usage(void) __attribute__((noreturn));
extern void limit_capabilities(struct ping_rts *rts);
#ifdef HAVE_LIBCAP
extern int modify_capability(struct ping_rts *rts, cap_value_t, cap_flag_value_t);
#else
extern int modify_capability(struct ping_rts *rts, int dummy __attribute__((__unused__)), int on);
# define CAP_NET_RAW 0
# define CAP_NET_ADMIN 0
# define CAP_SET 1
# define CAP_CLEAR 0
#endif

extern void drop_capabilities(void);

char *pr_addr(struct ping_rts *rts, void *sa, socklen_t salen);

int is_ours(struct ping_rts *rts, socket_st *sock, uint16_t id);
extern int pinger(struct ping_rts *rts, ping_func_set_st *fset, socket_st *sock);
extern void sock_setbufs(struct ping_rts *rts, socket_st *, int alloc);
extern void setup(struct ping_rts *rts, socket_st *);
extern int contains_pattern_in_payload(struct ping_rts *rts, uint8_t *ptr);
extern int main_loop(struct ping_rts *rts, ping_func_set_st *fset, socket_st*,
		     uint8_t *buf, int buflen);
extern int finish(struct ping_rts *rts);
extern void status(struct ping_rts *rts);
extern void common_options(int ch);
extern int gather_statistics(struct ping_rts *rts, uint8_t *ptr, int icmplen,
			     int cc, uint16_t seq, int hops,
			     int csfailed, struct timeval *tv, char *from,
			     void (*pr_reply)(uint8_t *ptr, int cc), int multicast);
extern void print_timestamp(struct ping_rts *rts);
void fill(struct ping_rts *rts, char *patp, unsigned char *packet, size_t packet_size);

/* IPv6 */

int ping6_run(struct ping_rts *rts, int argc, char **argv, struct addrinfo *ai,
	      socket_st *sock);
void ping6_usage(unsigned from_ping);

int ping6_send_probe(struct ping_rts *rts, socket_st *sockets, void *packet, unsigned packet_size);
int ping6_receive_error_msg(struct ping_rts *rts, socket_st *sockets);
int ping6_parse_reply(struct ping_rts *rts, socket_st *, struct msghdr *msg, int len, void *addr, struct timeval *);
void ping6_install_filter(struct ping_rts *rts, socket_st *sockets);
int ntohsp(uint16_t *p);

/* IPv6 node information query */

int niquery_is_enabled(struct ping_ni *ni);
void niquery_init_nonce(struct ping_ni *ni);
int niquery_option_handler(struct ping_ni *ni, const char *opt_arg);
int niquery_is_subject_valid(struct ping_ni *ni);
int niquery_check_nonce(struct ping_ni *ni, uint8_t *nonce);
void niquery_fill_nonce(struct ping_ni *ni, uint16_t seq, uint8_t *nonce);

#define NI_NONCE_SIZE			8

struct ni_hdr {
	struct icmp6_hdr		ni_u;
	uint8_t				ni_nonce[NI_NONCE_SIZE];
};

#define ni_type		ni_u.icmp6_type
#define ni_code		ni_u.icmp6_code
#define ni_cksum	ni_u.icmp6_cksum
#define ni_qtype	ni_u.icmp6_data16[0]
#define ni_flags	ni_u.icmp6_data16[1]

#endif /* IPUTILS_PING_H */
