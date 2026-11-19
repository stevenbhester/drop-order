// lm.c: the Last Mile level engine. Rules, solver, the two difficulty measures, and (in gen.c) the
// generator, in C because the generator needs to solve levels hundreds of thousands of times.
//
//   tools/engine/build.sh                      builds build/lm
//   python3 tools/engine/lv.py levels/levels.json | build/lm solve     count, cost and length per level
//   python3 tools/engine/lv.py levels/levels.json | build/lm score     every measure, one JSON object per level
//   python3 tools/engine/lv.py levels/levels.json | build/lm explain   the answer, junction by junction
//   build/lm gen key=value ...                 candidates for one slot of the plan (tools/engine/gen_all.py runs it)
//
// THE RULES HERE MUST MATCH scripts/sim.gd AND scripts/solver.gd EXACTLY. tools/engine/crosscheck.sh
// compares this solver with the game's own on every level (winning routes, search size, shortest route);
// run it after touching either. The game stays the judge: levels made here still go through
// tools/validate_levels.gd and the autotests.
//
// design/level_engine.md explains the ideas: the road view (someone who has to drive it to find out), the
// plan view (someone who thinks it through), and what Steven's playtests taught each of them.

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef unsigned __int128 u128;
#define BIT(i) (((u128)1) << (i))
#define MAXC 126     // cells on a map (9 x 12 is the biggest in the game)
#define MAXB 48      // houses, or shops
#define MAXR 220     // tiles in a route
#define MAXSTK 96
#define ANY 6        // an old-style locker's "colour" (takes whatever's on top, for good: the OG levels)
#define MAXL 4       // parking lockers (token L): keep one package until the van passes again
#define EMPTY 255
#define USE 4        // the move that uses a parking locker
#define NMOVES 5     // up, right, down, left, USE

// Directions in the game's order (LevelData.DIRS): up, right, down, left.
static const int DX[4] = {0, 1, 0, -1};
static const int DY[4] = {-1, 0, 1, 0};
static const char COLS[] = "rbgypo";

// ------------------------------------------------------------------ a level

typedef struct {
    int w, h, n, ret, start, has_exit, bad;
    char id[40];
    uint8_t road[MAXC], bridge[MAXC], hub[MAXC], ice[MAXC], works[MAXC];
    int8_t oneway[MAXC], gate[MAXC];
    int nh, hcell[MAXB], hcol[MAXB], hord[MAXB];
    int ns, scell[MAXB], scol[MAXB], scnt[MAXB];
    int nl, lcell[MAXL];
    int nstack;
    uint8_t stack0[MAXSTK];
    // Worked out by level_finish():
    int nb[MAXC][4];
    int nah[MAXC], nas[MAXC], nal[MAXC];
    uint8_t ah[MAXC][4], as_[MAXC][4], al[MAXC][4];
    u128 lroads[MAXL];
    u128 hroads[MAXB], sroads[MAXB], roadm, startnb, colL, colR, all;
    int total, nroad, nbridge, maxlen;
} Level;

static int colour_of(char c) {
    const char *p = strchr(COLS, c);
    return (p && c) ? (int)(p - COLS) : -1;
}

static void level_clear(Level *L, int w, int h) {
    memset(L, 0, sizeof *L);
    L->w = w;
    L->h = h;
    L->n = w * h;
    L->start = -1;
    for (int i = 0; i < MAXC; i++) {
        L->oneway[i] = -1;
        L->gate[i] = -1;
    }
}

// Neighbours, which buildings each road tile touches, and the masks the solver uses.
static void level_finish(Level *L) {
    L->roadm = 0;
    L->colL = L->colR = L->all = 0;
    L->nroad = L->nbridge = 0;
    for (int c = 0; c < L->n; c++) {
        int x = c % L->w, y = c / L->w;
        L->all |= BIT(c);
        if (x == 0) L->colL |= BIT(c);
        if (x == L->w - 1) L->colR |= BIT(c);
        if (L->road[c]) {
            L->roadm |= BIT(c);
            L->nroad++;
        }
        if (L->bridge[c]) L->nbridge++;
        L->nah[c] = L->nas[c] = L->nal[c] = 0;
        for (int d = 0; d < 4; d++) {
            int nx = x + DX[d], ny = y + DY[d];
            L->nb[c][d] = (nx >= 0 && ny >= 0 && nx < L->w && ny < L->h) ? ny * L->w + nx : -1;
        }
    }
    L->total = 0;
    for (int k = 0; k < L->nh; k++) {
        L->hroads[k] = 0;
        L->total += L->hord[k];
        for (int d = 0; d < 4; d++) {
            int rp = L->nb[L->hcell[k]][d];
            if (rp >= 0 && L->road[rp]) {
                L->hroads[k] |= BIT(rp);
                if (L->nah[rp] < 4) L->ah[rp][L->nah[rp]++] = (uint8_t)k;
            }
        }
    }
    for (int k = 0; k < L->ns; k++) {
        L->sroads[k] = 0;
        for (int d = 0; d < 4; d++) {
            int rp = L->nb[L->scell[k]][d];
            if (rp >= 0 && L->road[rp]) {
                L->sroads[k] |= BIT(rp);
                if (L->nas[rp] < 4) L->as_[rp][L->nas[rp]++] = (uint8_t)k;
            }
        }
    }
    for (int k = 0; k < L->nl; k++) {
        L->lroads[k] = 0;
        for (int d = 0; d < 4; d++) {
            int rp = L->nb[L->lcell[k]][d];
            if (rp >= 0 && L->road[rp]) {
                L->lroads[k] |= BIT(rp);
                if (L->nal[rp] < 4) L->al[rp][L->nal[rp]++] = (uint8_t)k;
            }
        }
    }
    L->startnb = 0;
    if (L->start >= 0)
        for (int d = 0; d < 4; d++)
            if (L->nb[L->start][d] >= 0) L->startnb |= BIT(L->nb[L->start][d]);
    L->maxlen = L->nroad + L->nbridge + 2 + 4 * L->nl;
}

// One token of a map row (LevelData._parse_token).
static void level_token(Level *L, int c, const char *t) {
    L->road[c] = 1;
    if (!strcmp(t, ".")) {
        L->road[c] = 0;
    } else if (!strcmp(t, "#")) {
    } else if (!strcmp(t, "S")) {
        L->start = c;
    } else if (!strcmp(t, "E")) {
        L->has_exit = 1;
    } else if (!strcmp(t, "+")) {
        L->bridge[c] = 1;
    } else if (!strcmp(t, "@")) {
        L->hub[c] = 1;
    } else if (!strcmp(t, "~")) {
        L->ice[c] = 1;
    } else if (!strcmp(t, "^")) {
        L->oneway[c] = 0;
    } else if (!strcmp(t, ">")) {
        L->oneway[c] = 1;
    } else if (!strcmp(t, "v")) {
        L->oneway[c] = 2;
    } else if (!strcmp(t, "<")) {
        L->oneway[c] = 3;
    } else if (t[0] == '=' && colour_of(t[1]) >= 0 && !t[2]) {
        L->gate[c] = (int8_t)colour_of(t[1]);
    } else if (t[0] == 'c' && t[1]) {
        int v = atoi(t + 1);
        L->works[c] = (uint8_t)(v < 1 ? 1 : v);
    } else if (!strcmp(t, "L")) {
        L->road[c] = 0;
        if (L->nl < MAXL) L->lcell[L->nl++] = c;
        else L->bad = 1;
    } else if (t[0] == 'w') {
        L->road[c] = 0;
        int v = t[1] ? atoi(t + 1) : 1;
        L->hcell[L->nh] = c;
        L->hcol[L->nh] = ANY;
        L->hord[L->nh++] = v < 1 ? 1 : v;
    } else if (colour_of(t[0]) >= 0) {
        L->road[c] = 0;
        int v = t[1] ? atoi(t + 1) : 1;
        L->hcell[L->nh] = c;
        L->hcol[L->nh] = colour_of(t[0]);
        L->hord[L->nh++] = v < 1 ? 1 : v;
    } else if (t[0] >= 'A' && t[0] <= 'Z' && colour_of((char)(t[0] + 32)) >= 0) {
        L->road[c] = 0;
        int v = t[1] ? atoi(t + 1) : 1;
        L->scell[L->ns] = c;
        L->scol[L->ns] = colour_of((char)(t[0] + 32));
        L->scnt[L->ns++] = v < 1 ? 1 : v;
    } else {
        L->road[c] = 0;
        L->bad = 1;
    }
}

// A line from tools/engine/lv.py: id, w, h, return, map, stack (tab-separated). 0 if it isn't one.
static int level_parse(Level *L, char *line) {
    char *f[6];
    int nf = 0;
    for (char *p = strtok(line, "\t\n"); p && nf < 6; p = strtok(NULL, "\t\n")) f[nf++] = p;
    if (nf < 6) return 0;
    int w = atoi(f[1]), h = atoi(f[2]);
    if (w < 1 || h < 1 || w * h > MAXC) return 0;
    level_clear(L, w, h);
    snprintf(L->id, sizeof L->id, "%s", f[0]);
    L->ret = atoi(f[3]);
    int c = 0;
    char tok[16];
    int tl = 0;
    for (char *p = f[4];; p++) {
        if (*p == ' ' || *p == '/' || *p == 0) {
            if (tl > 0) {
                tok[tl] = 0;
                if (c < L->n) level_token(L, c, tok);
                c++;
                tl = 0;
            }
            if (*p == 0) break;
        } else if (tl < 15) {
            tok[tl++] = *p;
        }
    }
    if (c != L->n || L->start < 0) L->bad = 1;
    L->nstack = 0;
    if (strcmp(f[5], "-"))
        for (char *p = f[5]; *p; p++)
            if (colour_of(*p) >= 0) L->stack0[L->nstack++] = (uint8_t)colour_of(*p);
    level_finish(L);
    return 1;
}

// ------------------------------------------------------------------ the rules (scripts/sim.gd)

typedef struct {
    int pos, prev, len, sp, deliv, parked;
    u128 vis, bh, bv;      // tiles driven; bridges entered sideways / up-and-down
    uint8_t stk[MAXSTK];
    uint8_t fill[MAXB], pick[MAXB];
    uint8_t held[MAXL];    // what each parking locker keeps (EMPTY: nothing)
    uint8_t acted;         // the last move was USE (the next can't be)
} State;

// What happened on arriving somewhere, for the analysis: 'd' house, 'p' shop, 's' swap, 'k' parked in a
// locker, 'u' given back by one.
typedef struct {
    int n;
    char type[24];
    uint8_t who[24];
} Events;

static void state_init(const Level *L, State *s) {
    memset(s, 0, sizeof *s);
    s->pos = L->start;
    s->prev = -1;
    s->len = 1;
    s->sp = L->nstack;
    memcpy(s->stk, L->stack0, (size_t)L->nstack);
    memset(s->held, EMPTY, sizeof s->held);
    s->vis = BIT(L->start);
}

// Sim.can_extend: the tile that way, or -1. Move USE (4) is using the parking locker beside the van (the van
// stays put: the tile is its own), once per stop (Solver: twice would only undo it).
static inline int can_extend(const Level *L, const State *s, int d) {
    if (d == USE) {
        if (s->acted || s->parked || !L->nal[s->pos]) return -1;
        int k = L->al[s->pos][0];
        return (s->held[k] != EMPTY || s->sp > 0) ? s->pos : -1;
    }
    int nx = L->nb[s->pos][d];
    if (nx < 0 || !L->road[nx] || s->parked) return -1;
    if (L->oneway[nx] >= 0 && L->oneway[nx] == (d ^ 2)) return -1;
    if (L->oneway[s->pos] >= 0 && L->oneway[s->pos] != d) return -1;
    if (L->gate[nx] >= 0 && (s->sp == 0 || s->stk[s->sp - 1] != L->gate[nx])) return -1;
    if (L->works[nx] && s->deliv < L->works[nx]) return -1;
    if (s->len >= 2 && d != s->prev && (L->ice[s->pos] || L->bridge[s->pos])) return -1;
    if (L->bridge[nx]) return (((d & 1) ? s->bh : s->bv) & BIT(nx)) ? -1 : nx;
    if (s->vis & BIT(nx)) return (L->ret && nx == L->start) ? nx : -1;
    return nx;
}

static inline void arrive_buildings(const Level *L, State *s, int t, Events *ev);

// Sim.arrive: the hub's swap, then deliveries and pickups until nothing more happens. (Parking lockers do
// nothing on arrival: using one is a move of its own, USE.)
static inline void arrive(const Level *L, State *s, int t, Events *ev) {
    if (L->hub[t] && s->sp >= 2) {
        uint8_t a = s->stk[s->sp - 1];
        s->stk[s->sp - 1] = s->stk[s->sp - 2];
        s->stk[s->sp - 2] = a;
        if (ev && ev->n < 24) ev->type[ev->n++] = 's';
    }
    if (L->nah[t] || L->nas[t]) arrive_buildings(L, s, t, ev);
}

// Sim.use_locker: stopped beside a parking locker, the player taps it: it gives back what it keeps (on top),
// or keeps the top package. Then deliveries and pickups there, as on arriving.
static inline void use_locker(const Level *L, State *s, Events *ev) {
    int t = s->pos, k = L->al[t][0];
    if (s->held[k] != EMPTY) {
        if (s->sp < MAXSTK) s->stk[s->sp++] = s->held[k];
        s->held[k] = EMPTY;
        if (ev && ev->n < 24) {
            ev->type[ev->n] = 'u';
            ev->who[ev->n++] = (uint8_t)k;
        }
    } else {
        s->held[k] = s->stk[--s->sp];
        if (ev && ev->n < 24) {
            ev->type[ev->n] = 'k';
            ev->who[ev->n++] = (uint8_t)k;
        }
    }
    if (L->nah[t] || L->nas[t]) arrive_buildings(L, s, t, ev);
}

// Deliveries and pickups at tile t until nothing more happens.
static inline void arrive_buildings(const Level *L, State *s, int t, Events *ev) {
    for (;;) {
        int progress = 0;
        if (s->sp > 0) {
            int top = s->stk[s->sp - 1];
            for (int any = 0; any < 2 && !progress; any++)
                for (int i = 0; i < L->nah[t]; i++) {
                    int k = L->ah[t][i];
                    if ((L->hcol[k] == ANY) == any && (any || L->hcol[k] == top) && s->fill[k] < L->hord[k]) {
                        s->fill[k]++;
                        s->sp--;
                        s->deliv++;
                        progress = 1;
                        if (ev && ev->n < 24) {
                            ev->type[ev->n] = 'd';
                            ev->who[ev->n++] = (uint8_t)k;
                        }
                        break;
                    }
                }
        }
        if (progress) continue;
        for (int i = 0; i < L->nas[t]; i++) {
            int k = L->as_[t][i];
            if (s->pick[k] < L->scnt[k]) {
                s->pick[k]++;
                if (s->sp < MAXSTK) s->stk[s->sp++] = (uint8_t)L->scol[k];
                progress = 1;
                if (ev && ev->n < 24) {
                    ev->type[ev->n] = 'p';
                    ev->who[ev->n++] = (uint8_t)k;
                }
                break;
            }
        }
        if (!progress) return;
    }
}

static inline void step(const Level *L, State *s, int d, int nx, Events *ev) {
    if (d == USE) {
        s->acted = 1;
        s->len++;
        use_locker(L, s, ev);
        return;
    }
    s->acted = 0;
    if (L->bridge[nx]) {
        if (d & 1)
            s->bh |= BIT(nx);
        else
            s->bv |= BIT(nx);
    } else {
        s->vis |= BIT(nx);
    }
    s->pos = nx;
    s->prev = d;
    s->len++;
    if (L->ret && nx == L->start) s->parked = 1;
    arrive(L, s, nx, ev);
}

static inline int won(const Level *L, const State *s) {
    return s->deliv == L->total && (!L->ret || s->parked);
}

static inline int has_move(const Level *L, const State *s) {
    for (int d = 0; d < NMOVES; d++)
        if (can_extend(L, s, d) >= 0) return 1;
    return 0;
}

// Every tile still reachable over road that isn't used up (the van's own tile counts).
static inline u128 reach_of(const Level *L, const State *s) {
    u128 freem = (L->roadm & ~(s->vis | (s->bh & s->bv))) | BIT(s->pos);
    u128 r = BIT(s->pos);
    for (;;) {
        u128 n = (r | ((r & ~L->colR) << 1) | ((r & ~L->colL) >> 1) | (r << L->w) | (r >> L->w)) & freem;
        if (n == r) return r;
        r = n;
    }
}

// Solver._hopeless: something still needed can't be reached any more.
static inline int hopeless(const Level *L, const State *s) {
    if (s->parked) return 1;
    u128 r = reach_of(L, s) & ~BIT(s->pos);
    for (int k = 0; k < L->nh; k++)
        if (s->fill[k] < L->hord[k] && !(L->hroads[k] & r)) return 1;
    for (int k = 0; k < L->ns; k++)
        if (s->pick[k] < L->scnt[k] && !(L->sroads[k] & r)) return 1;
    for (int k = 0; k < L->nl; k++)
        if (s->held[k] != EMPTY && !(L->lroads[k] & r)) return 1;
    if (L->ret && !((r | BIT(s->pos)) & L->startnb)) return 1;
    return 0;
}

// ------------------------------------------------------------------ the solver (scripts/solver.gd)

typedef struct {
    long count, nodes, limit, node_limit;
    int capped, short_len, keep, nkept, maxkeep;
    long nshort;                   // winning routes of the shortest length
    int cur[MAXR], shortest[MAXR];
    int (*routes)[MAXR];
    int *rlen;
} Solve;

static void solve_dfs(const Level *L, Solve *S, const State *s) {
    if (S->count >= S->limit || S->nodes >= S->node_limit) {
        S->capped = 1;
        return;
    }
    S->nodes++;
    for (int d = 0; d < NMOVES; d++) {
        int nx = can_extend(L, s, d);
        if (nx < 0) continue;
        State t = *s;
        step(L, &t, d, nx, NULL);
        S->cur[t.len - 1] = nx;
        if (won(L, &t)) {
            S->count++;
            if (S->keep && S->nkept < S->maxkeep) {
                memcpy(S->routes[S->nkept], S->cur, sizeof(int) * (size_t)t.len);
                S->rlen[S->nkept++] = t.len;
            }
            if (t.len == S->short_len) S->nshort++;
            if (S->short_len == 0 || t.len < S->short_len) {
                S->nshort = 1;
                S->short_len = t.len;
                memcpy(S->shortest, S->cur, sizeof(int) * (size_t)t.len);
            }
        } else if (t.len < L->maxlen && t.len < MAXR - 1 && !hopeless(L, &t)) {
            solve_dfs(L, S, &t);
        }
    }
}

static void solve(const Level *L, Solve *S, long limit, long node_limit) {
    S->count = S->nodes = S->nshort = 0;
    S->capped = S->short_len = S->nkept = 0;
    S->limit = limit;
    S->node_limit = node_limit;
    State s;
    state_init(L, &s);
    S->cur[0] = L->start;
    solve_dfs(L, S, &s);
}

// ------------------------------------------------------------------ commands

static int cmd_solve(void) {
    static char line[8192];
    static Level L;
    static Solve S;
    while (fgets(line, sizeof line, stdin)) {
        if (!level_parse(&L, line)) continue;
        if (L.bad || L.has_exit) {
            printf("%s skip\n", L.id);
            continue;
        }
        memset(&S, 0, sizeof S);
        solve(&L, &S, 20000, 4000000);
        printf("%s %ld %d %ld %d\n", L.id, S.count, S.capped, S.nodes, S.short_len > 0 ? S.short_len - 1 : -1);
    }
    return 0;
}

// Every winning route's length (for fuel levels: the tank holds the shortest). "id: count, shortest, then
// length:how many" per level.
static int g_hist[MAXR];
static void lens_dfs(const Level *L, const State *s, long *budget) {
    if ((*budget)-- <= 0) return;
    for (int d = 0; d < NMOVES; d++) {
        int nx = can_extend(L, s, d);
        if (nx < 0) continue;
        State t = *s;
        step(L, &t, d, nx, NULL);
        if (won(L, &t))
            g_hist[t.len - 1]++;
        else if (t.len < L->maxlen && t.len < MAXR - 1 && !hopeless(L, &t))
            lens_dfs(L, &t, budget);
    }
}

static int cmd_lens(void) {
    static char line[8192];
    static Level L;
    while (fgets(line, sizeof line, stdin)) {
        if (!level_parse(&L, line) || L.bad || L.has_exit) continue;
        memset(g_hist, 0, sizeof g_hist);
        long budget = 20000000;
        State s;
        state_init(&L, &s);
        lens_dfs(&L, &s, &budget);
        printf("%s:", L.id);
        for (int i = 0; i < MAXR; i++)
            if (g_hist[i]) printf(" %d:%d", i, g_hist[i]);
        printf("\n");
    }
    return 0;
}

#ifndef LM_NO_MAIN
int cmd_score(int argc, char **argv);
int cmd_explain(int argc, char **argv);
int cmd_gen(int argc, char **argv);

int main(int argc, char **argv) {
    if (argc >= 2 && !strcmp(argv[1], "solve")) return cmd_solve();
    if (argc >= 2 && !strcmp(argv[1], "lens")) return cmd_lens();
    if (argc >= 2 && !strcmp(argv[1], "score")) return cmd_score(argc, argv);
    if (argc >= 2 && !strcmp(argv[1], "explain")) return cmd_explain(argc, argv);
    if (argc >= 2 && !strcmp(argv[1], "gen")) return cmd_gen(argc, argv);
    fprintf(stderr, "usage: lm solve | score | gen key=value ...\n");
    return 2;
}
#endif

// ------------------------------------------------------------------ the road view
//
// How hard is it for someone who has to DRIVE it to find out? Right about beginners. It overrates levels
// for experienced players, who think in plans (see the plan view, further down): in an open grid one
// idea can be driven a dozen ways, and this view counts every one.
//
// THE PLAYER MODEL ("the explorer"). Someone who connects the dots and learns from it:
//   - they head for the next delivery. What draws them down a road is how soon it delivers something, by
//     the best line down it that isn't a dead end they can see (so a road whose obvious continuation is
//     visibly fatal, leaving only a long way round, looks like a bad road). A road 3 tiles slower is tried
//     first about a third as often;
//   - they can read two kinds of dead end off the map and don't drive into them: a move that leaves
//     nowhere to go, and a move that uses up the LAST DOOR of a building that still needs a package (a
//     house with one door is a signal: don't pass it until its colour is on top). How far down a forced
//     road they see one coming depends on the player (below);
//   - everything else they find out by driving: a TRY ends when something still needed can no longer be
//     reached. They remember what failed and don't repeat it.
//
// From the whole tree of possible drives we then get, in units a player would recognise:
//   tries    how many failed tries to expect before the win. A dead branch costs less than its size (people
//            give up on a bad idea before exhausting it) and more if it delivers packages before it dies
//            (it looked like it was working).
//   first    the chance a first, unthinking attempt wins. Connect-the-dots levels score high.
//   exhaust  the share of ALL the wrong lines the explorer goes through first. Near 1 on a small level is
//            the "this must be bugged" feeling: you tried everything you could think of.
// THREE PLAYERS, because the door signal is learned:
//   new      hasn't learned it: only sees a road with nowhere to go
//   regular  uses it, and sees it coming two tiles down a forced road
//   expert   sees it however far down a forced road it is
// A level is scored for the player who'd be playing it (new players early in the game, experts late).
//
// and along the winning line the explorer most likely finds:
//   twist    a junction that costs about a try or more: the inviting moves are wrong
//   fork     a junction that costs a fraction of one
//   away     the right move leads AWAY from the next delivery while something more direct is on offer
//   near     a wrong road that delivers everything but one package

#define MAXSOL 24
#define FAR 99
static double TAU = 4.0;
static int g_doors = 1, g_sight = 2;      // the player: knows the door signal; how far ahead they see a dead end

static void set_player(int who) {
    g_doors = who > 0;
    g_sight = who == 0 ? 1 : (who == 1 ? 2 : 99);
}

typedef struct {
    double wins, leaves;      // winning lines and failed tries below here
    long nodes;
    int reach;                // the most deliveries made anywhere below
    double E, U, F;           // tries, tries with nothing given up early, first-attempt chance
    double tsum;              // along the likeliest winning line: the junction costs (each capped at 3)
    short twists, forks, nears, dec, away, gap, len;
    uint8_t ntw, tw[8];       // where the twists are (tile index along the line)
    short next;               // tiles from here to the next delivery, by the best line that isn't visibly dead
    short nexta;              // ...by any line at all
    short pd;                 // -1, or: everything from here is visibly dead within this many tiles
    uint8_t opening;          // the first real choice on the line is a twist
    uint8_t nnr, nr[4];       // where the near misses branch off
} Sub;

// A building that still needs a package has had every one of its doors driven past.
static inline int doors_gone(const Level *L, const State *s) {
    for (int k = 0; k < L->nh; k++)
        if (s->fill[k] < L->hord[k] && !(L->hroads[k] & ~s->vis)) return 1;
    for (int k = 0; k < L->nl; k++)
        if (s->held[k] != EMPTY && !(L->lroads[k] & ~s->vis)) return 1;
    return 0;
}

static long g_budget;
static int g_over;
static int g_line[MAXR][MAXR], g_rt[MAXR][4][MAXR];

// Where the player wants to go next: the tiles from which the top package can be delivered; if nobody
// wants it, wherever the load can change (a locker, a pickup, a hub); with nothing left, home.
static u128 targets(const Level *L, const State *s) {
    u128 tg = 0;
    if (s->sp > 0) {
        int top = s->stk[s->sp - 1];
        for (int k = 0; k < L->nh; k++)
            if (L->hcol[k] == top && s->fill[k] < L->hord[k]) tg |= L->hroads[k];
        if (!tg)
            for (int k = 0; k < L->nh; k++)
                if (L->hcol[k] == ANY && s->fill[k] < L->hord[k]) tg |= L->hroads[k];
    }
    if (!tg) {
        for (int k = 0; k < L->ns; k++)
            if (s->pick[k] < L->scnt[k]) tg |= L->sroads[k];
        for (int k = 0; k < L->nl; k++)
            if (s->held[k] != EMPTY || s->sp > 0) tg |= L->lroads[k];
        if (s->sp >= 2)
            for (int c = 0; c < L->n; c++)
                if (L->hub[c]) tg |= BIT(c);
    }
    if (!tg && L->ret) tg = BIT(L->start);
    return tg;
}

// Tiles to drive from where `s` is until the van is ON a target tile, by the rules as they stand now
// (one-ways, ice, bridges, gates for what's on top, roadworks for what's delivered, road already used).
static int dist_to(const Level *L, const State *s, u128 tg) {
    if (tg & BIT(s->pos)) return 0;
    if (!tg) return FAR;
    static uint8_t seen[MAXC * 5];
    static int qc[MAXC * 5], qp[MAXC * 5], qd[MAXC * 5];
    memset(seen, 0, (size_t)L->n * 5);
    int head = 0, tail = 0;
    int p0 = s->len >= 2 ? s->prev : 4;
    qc[tail] = s->pos;
    qp[tail] = p0;
    qd[tail++] = 0;
    seen[s->pos * 5 + p0] = 1;
    while (head < tail) {
        int c = qc[head], p = qp[head], dd = qd[head];
        head++;
        for (int d = 0; d < 4; d++) {
            int nx = L->nb[c][d];
            if (nx < 0 || !L->road[nx]) continue;
            if (L->oneway[nx] >= 0 && L->oneway[nx] == (d ^ 2)) continue;
            if (L->oneway[c] >= 0 && L->oneway[c] != d) continue;
            if (L->gate[nx] >= 0 && (s->sp == 0 || s->stk[s->sp - 1] != L->gate[nx])) continue;
            if (L->works[nx] && s->deliv < L->works[nx]) continue;
            if (p != 4 && d != p && (L->ice[c] || L->bridge[c])) continue;
            if (L->bridge[nx]) {
                if (((d & 1) ? s->bh : s->bv) & BIT(nx)) continue;
            } else if (s->vis & BIT(nx)) {
                if (!(L->ret && nx == L->start && (tg & BIT(nx)))) continue;
            }
            if (tg & BIT(nx)) return dd + 1;
            if (seen[nx * 5 + d]) continue;
            seen[nx * 5 + d] = 1;
            qc[tail] = nx;
            qp[tail] = d;
            qd[tail++] = dd + 1;
        }
    }
    return FAR;
}

enum { K_PLAIN, K_WIN, K_LEAF, K_OPEN };

// One state and the roads out of it, as the explorer sees them.
typedef struct {
    int nch, live, nwin, best, amin, nears;
    State t[4];
    Sub sub[4];
    int kind[4], cell[4], stepd[4], att[4], dv[4], hidden[4];
    double w[4], p[4], de[4];      // pull; for a dead road, the chance it's tried before a winning one, and what it costs
    double c, cu, W, A;
} Junction;

static Sub walk(const Level *L, const State *s);

static void junction(const Level *L, const State *s, Junction *J) {
    int k = s->len - 1;
    J->nch = J->live = J->nwin = J->nears = 0;
    J->best = -1;
    J->c = J->cu = J->W = J->A = 0;
    J->amin = 0;
    for (int d = 0; d < NMOVES; d++) {
        int nx = can_extend(L, s, d);
        if (nx < 0) continue;
        int i = J->nch++;
        State *t = &J->t[i];
        *t = *s;
        step(L, t, d, nx, NULL);
        J->cell[i] = nx;
        memset(&J->sub[i], 0, sizeof(Sub));
        J->sub[i].reach = t->deliv;
        J->sub[i].next = J->sub[i].nexta = FAR;
        J->sub[i].pd = -1;
        J->dv[i] = J->hidden[i] = 0;
        if (won(L, t)) {
            J->kind[i] = K_WIN;
            J->sub[i].wins = 1;
            J->sub[i].F = 1;
            J->sub[i].reach = L->total;
        } else if (!has_move(L, t) || (g_doors && doors_gone(L, t))) {
            J->kind[i] = K_PLAIN;
        } else if (t->len >= L->maxlen || t->len >= MAXR - 1 || hopeless(L, t)) {
            J->kind[i] = K_LEAF;
            J->sub[i].leaves = 1;
        } else {
            J->kind[i] = K_OPEN;
        }
    }
    for (int i = 0; i < J->nch; i++) {
        if (J->kind[i] == K_OPEN) {
            J->sub[i] = walk(L, &J->t[i]);
            if (J->sub[i].wins > 0 && k + 1 < MAXR) memcpy(g_rt[k][i], g_line[k + 1], sizeof(int) * (size_t)J->sub[i].len);
            if (J->sub[i].pd >= 0) {
                if (J->sub[i].pd <= g_sight) {
                    J->kind[i] = K_PLAIN;
                    J->dv[i] = J->sub[i].pd;
                } else {
                    // Dead, and you could have seen it from closer up, but not from here: a try.
                    J->kind[i] = K_LEAF;
                    J->hidden[i] = 1;
                    J->sub[i].leaves = 1;
                    J->sub[i].nodes = 1;
                }
            }
        }
        if (J->kind[i] != K_PLAIN) J->live++;
        if (J->sub[i].wins > 0) J->nwin++;
    }
    // How far to the next delivery down each road (as far as anyone can tell without driving it).
    int m = FAR;
    for (int i = 0; i < J->nch; i++) {
        J->stepd[i] = FAR;
        J->att[i] = 0;
        J->w[i] = 1;
        J->p[i] = J->de[i] = 0;
        if (J->kind[i] == K_PLAIN) continue;
        if (J->t[i].deliv > s->deliv || J->kind[i] == K_WIN)
            J->stepd[i] = 1;
        else if (J->kind[i] == K_OPEN)
            J->stepd[i] = 1 + J->sub[i].next;
        if (J->stepd[i] < m) m = J->stepd[i];
    }
    for (int i = 0; i < J->nch; i++) {
        // A road that's already lost (something's cut off) but doesn't look it: judge it by the map.
        if (J->kind[i] != K_LEAF || J->t[i].deliv > s->deliv) continue;
        if (J->hidden[i])
            J->stepd[i] = 1 + J->sub[i].nexta;
        else if ((J->nwin > 0 && J->live >= 2) || m > 2)
            J->stepd[i] = 1 + dist_to(L, &J->t[i], targets(L, &J->t[i]));
        if (J->stepd[i] < m) m = J->stepd[i];
    }
    J->amin = m;
    if (J->nwin == 0) return;
    if (J->live >= 2)
        for (int i = 0; i < J->nch; i++) {
            if (J->kind[i] == K_PLAIN) continue;
            J->att[i] = (J->stepd[i] > FAR ? FAR : J->stepd[i]) - 1;
            J->w[i] = exp(-(J->att[i] - (m - 1)) / TAU);
        }
    for (int i = 0; i < J->nch; i++) {
        if (J->kind[i] == K_PLAIN) continue;
        J->A += J->w[i];
        if (J->sub[i].wins > 0) J->W += J->w[i];
    }
    int rem = L->total - s->deliv;
    int need = rem - 1 < 2 ? rem - 1 : 2;
    if (need < 1) need = 1;
    for (int i = 0; i < J->nch; i++) {
        if (J->kind[i] == K_PLAIN) continue;
        const Sub *b = &J->sub[i];
        if (b->wins > 0) {
            if (J->best < 0 || J->w[i] > J->w[J->best] + 1e-12 || (fabs(J->w[i] - J->w[J->best]) <= 1e-12 && b->F > J->sub[J->best].F)) J->best = i;
        } else {
            double gain = (double)(b->reach - s->deliv) / need;
            J->p[i] = J->w[i] / (J->w[i] + J->W);
            J->de[i] = pow(b->leaves, 0.6) * (0.5 + 0.5 * (gain > 1 ? 1 : gain));
            J->c += J->p[i] * J->de[i];
            J->cu += J->p[i] * b->leaves;
            if (J->p[i] >= 0.25 && rem >= 3 && b->reach >= L->total - 1) J->nears++;
        }
    }
}

// The whole tree below a state, as the explorer meets it.
static Sub walk(const Level *L, const State *s) {
    Sub r;
    memset(&r, 0, sizeof r);
    r.nodes = 1;
    r.reach = s->deliv;
    r.next = r.nexta = FAR;
    r.pd = -1;
    if (g_budget-- <= 0) {
        g_over = 1;
        r.leaves = 1;
        return r;
    }
    int k = s->len - 1;
    Junction J;
    junction(L, s, &J);
    for (int i = 0; i < J.nch; i++) {
        if (J.kind[i] == K_PLAIN) continue;        // nobody drives into those: they cost nothing
        r.wins += J.sub[i].wins;
        r.leaves += J.sub[i].leaves;
        r.nodes += J.sub[i].nodes;
        if (J.sub[i].reach > r.reach) r.reach = J.sub[i].reach;
    }
    if (J.live == 0) {                   // nothing here but dead ends you can see coming
        int far = 0;
        for (int i = 0; i < J.nch; i++)
            if (J.dv[i] > far) far = J.dv[i];
        r.pd = (short)(far + 1);
    }
    r.next = (short)(J.amin > FAR ? FAR : J.amin);
    int na = FAR;
    for (int i = 0; i < J.nch; i++) {
        int v = FAR;
        if (J.t[i].deliv > s->deliv || J.kind[i] == K_WIN)
            v = 1;
        else if (J.sub[i].nexta < FAR)
            v = 1 + J.sub[i].nexta;
        if (v < na) na = v;
    }
    r.nexta = (short)na;
    if (J.nwin == 0) return r;
    for (int i = 0; i < J.nch; i++)
        if (J.kind[i] != K_PLAIN && J.sub[i].wins > 0) {
            r.E += J.w[i] / J.W * J.sub[i].E;
            r.U += J.w[i] / J.W * J.sub[i].U;
            r.F += J.w[i] / J.A * J.sub[i].F;
        }
    r.E += J.c;
    r.U += J.cu;
    // The likeliest winning line from here.
    const Sub *b = &J.sub[J.best];
    r.tsum = b->tsum;
    r.twists = b->twists;
    r.forks = b->forks;
    r.nears = b->nears;
    r.dec = b->dec;
    r.away = b->away;
    r.gap = b->gap;
    r.ntw = b->ntw;
    memcpy(r.tw, b->tw, sizeof r.tw);
    r.opening = b->opening;
    r.nnr = b->nnr;
    memcpy(r.nr, b->nr, sizeof r.nr);
    r.len = (short)(b->len + 1);
    g_line[k][0] = J.cell[J.best];
    if (b->len > 0) memcpy(g_line[k] + 1, g_rt[k][J.best], sizeof(int) * (size_t)b->len);
    if (J.live >= 2) {
        r.dec++;
        r.tsum += J.c > 3 ? 3 : J.c;
        r.nears = (short)(r.nears + J.nears);
        r.opening = J.c >= 0.75;
        if (J.nears && r.nnr < 4) {
            memmove(r.nr + 1, r.nr, r.nnr);
            r.nr[0] = (uint8_t)k;
            r.nnr++;
        }
        if (J.c >= 0.75) {
            r.twists++;
            if (r.ntw < 8) {
                memmove(r.tw + 1, r.tw, r.ntw);
                r.tw[0] = (uint8_t)k;
                r.ntw++;
            }
        } else if (J.c >= 0.3) {
            r.forks++;
        }
        if (J.att[J.best] > J.amin - 1 + 1) {
            r.away++;
            if (J.att[J.best] - (J.amin - 1) > r.gap) r.gap = (short)(J.att[J.best] - (J.amin - 1));
        }
    }
    return r;
}

// ------------------------------------------------------------------ the plan view
//
// An experienced player doesn't think in road tiles. They think in PLANS: which building next, through
// which door. Two drives that make the same stops through the same doors are the same idea, however the
// road between wiggles, and a stop that plainly strands something is ruled out without trying it.
//
// So: every drive the solver would consider (it gives up the moment something needed can't be reached),
// collapsed to its sequence of stops. That's a tree of plans. On it we run the same explorer as before:
// what draws them to a stop is how soon it comes; a wrong stop costs by how many different plans there
// are to try beyond it before it's refuted.
//   pnodes    partial plans that aren't plainly dead (the size of what there is to hold in your head)
//   plans     complete wrong plans (dead ends that needed thinking through), plus the answers
//   ptries    wrong plans to expect to work through before the answer
//   pfirst    the chance the first plan that comes to mind is the answer
//   pdec      stops on the answer where there was a real alternative; ptwists: where it costs a plan or more

static double PTAU = 4.0;        // how strongly the planner prefers the nearest stop (smaller = more strongly)
#define PMAX 400000
#define PHASH (1 << 20)
typedef struct {
    uint64_t key;
    int parent, first, next, leg, reach;
    double leaves, E, F;
    uint8_t win;
} PNode;
static PNode *g_pn;
static int *g_ph, g_npn;
static long g_pbudget;
static int g_pover;

static int plan_child(int parent, uint64_t key, int leg, int reach) {
    uint32_t h = (uint32_t)(key ^ (key >> 29)) & (PHASH - 1);
    while (g_ph[h]) {
        PNode *q = &g_pn[g_ph[h] - 1];
        if (q->key == key && q->parent == parent) {
            if (leg < q->leg) q->leg = leg;
            return g_ph[h] - 1;
        }
        h = (h + 1) & (PHASH - 1);
    }
    if (g_npn >= PMAX) {
        g_pover = 1;
        return -1;
    }
    PNode *q = &g_pn[g_npn];
    memset(q, 0, sizeof *q);
    q->key = key;
    q->parent = parent;
    q->first = q->next = -1;
    q->leg = leg;
    q->reach = reach;
    if (parent >= 0) {
        q->next = g_pn[parent].first;
        g_pn[parent].first = g_npn;
    }
    g_ph[h] = g_npn + 1;
    return g_npn++;
}

static void plan_dfs(const Level *L, const State *s, int node, int since) {
    if (g_pbudget-- <= 0) {
        g_pover = 1;
        return;
    }
    for (int d = 0; d < NMOVES; d++) {
        int nx = can_extend(L, s, d);
        if (nx < 0) continue;
        State t = *s;
        Events ev = {0};
        step(L, &t, d, nx, &ev);
        int w = won(L, &t);
        if (!w && (t.len >= L->maxlen || t.len >= MAXR - 1 || hopeless(L, &t))) continue;
        if (ev.n == 0 && !w) {
            plan_dfs(L, &t, node, since + 1);
            continue;
        }
        uint64_t key = (g_pn[node].key ^ (uint64_t)(nx + 1)) * 1099511628211ULL;
        for (int e = 0; e < ev.n; e++) key = (key ^ (uint64_t)(ev.type[e] * 64 + ev.who[e] + 1)) * 1099511628211ULL;
        int c = plan_child(node, key, since + 1, t.deliv);
        if (c < 0) continue;
        if (w)
            g_pn[c].win = 1;
        else
            plan_dfs(L, &t, c, 0);
    }
}

typedef struct {
    int pnodes, pdec, ptwists, over;
    int pdev;                      // stops on the answer that aren't the nearest stop on offer: the surprises
    int pstops;
    double plans, ptries, pfirst;
} PlanView;

static void plan_view(const Level *L, PlanView *V, long budget) {
    memset(V, 0, sizeof *V);
    if (!g_pn) {
        g_pn = malloc(sizeof(PNode) * PMAX);
        g_ph = malloc(sizeof(int) * PHASH);
    }
    memset(g_ph, 0, sizeof(int) * PHASH);
    g_npn = 0;
    g_pover = 0;
    g_pbudget = budget;
    State s;
    state_init(L, &s);
    plan_child(-1, 1469598103934665603ULL, 0, 0);
    plan_dfs(L, &s, 0, 0);
    // Children come after their parents, so one pass backwards rolls everything up.
    for (int i = g_npn - 1; i >= 0; i--) {
        PNode *q = &g_pn[i];
        if (q->win) {
            q->F = 1;
        } else if (q->first < 0) {
            q->leaves = 1;
        } else {
            int legmin = 1 << 30;
            double W = 0, A = 0;
            for (int c = q->first; c >= 0; c = g_pn[c].next)
                if (g_pn[c].leg < legmin) legmin = g_pn[c].leg;
            for (int c = q->first; c >= 0; c = g_pn[c].next) {
                double w = exp(-(g_pn[c].leg - legmin) / PTAU);
                A += w;
                if (g_pn[c].win) W += w;
            }
            int rem = L->total - q->reach, need = rem - 1 < 2 ? rem - 1 : 2;
            if (need < 1) need = 1;
            for (int c = q->first; c >= 0; c = g_pn[c].next) {
                const PNode *k = &g_pn[c];
                double w = exp(-(k->leg - legmin) / PTAU);
                if (k->reach > q->reach) q->reach = k->reach;        // (rolled up: the most delivered anywhere below)
                if (k->win) {
                    q->win = 1;
                } else {
                    q->leaves += k->leaves;
                }
                if (W > 0) {
                    if (k->win) {
                        q->E += w / W * k->E;
                        q->F += w / A * k->F;
                    } else {
                        double gain = (double)(k->reach - g_pn[i].reach) / need;
                        (void)gain;
                        q->E += w / (w + W) * pow(k->leaves, 0.6);
                    }
                }
            }
        }
    }
    V->pnodes = g_npn;
    V->plans = g_pn[0].leaves;
    V->ptries = g_pn[0].E;
    V->pfirst = g_pn[0].F;
    V->over = g_pover;
    // Down the likeliest winning plan: where were the real alternatives?
    for (int i = 0; g_pn[i].first >= 0 && g_pn[i].win;) {
        int best = -1, kids = 0, legmin = 1 << 30;
        double W = 0, cost = 0;
        for (int c = g_pn[i].first; c >= 0; c = g_pn[c].next) {
            kids++;
            if (g_pn[c].leg < legmin) legmin = g_pn[c].leg;
        }
        for (int c = g_pn[i].first; c >= 0; c = g_pn[c].next)
            if (g_pn[c].win) {
                W += exp(-(g_pn[c].leg - legmin) / PTAU);
                if (best < 0 || g_pn[c].leg < g_pn[best].leg) best = c;
            }
        for (int c = g_pn[i].first; c >= 0; c = g_pn[c].next)
            if (!g_pn[c].win) {
                double w = exp(-(g_pn[c].leg - legmin) / PTAU);
                cost += w / (w + W) * pow(g_pn[c].leaves, 0.6);
            }
        if (kids >= 2) V->pdec++;
        if (cost >= 0.75) V->ptwists++;
        if (best < 0) break;
        V->pstops++;
        if (g_pn[best].leg >= legmin + 2) V->pdev++;
        i = best;
    }
}

typedef struct {
    int len, turns, late_drops, dumps, pickups, swaps, max_load, used_gate, used_works, used_ice, used_oneway, used_bridge2;
    int quiet;                     // the longest stretch with no delivery
    int picks;                     // deliveries where more than one building could have taken the package
    int buried;                    // pickups that landed on top of something
    int last_doors;                // doors on the house that gets the last package (1 = it gives the ending away)
    double cover;
} Drive;

// What a route does, tile by tile. 0 if it isn't a legal drive.
static int drive(const Level *L, const int *route, int len, Drive *P) {
    memset(P, 0, sizeof *P);
    P->len = len - 1;
    State s;
    state_init(L, &s);
    int passed[MAXB] = {0}, parked_at[MAXL] = {0};
    u128 seenb = 0, usedm = BIT(route[0]);
    P->max_load = s.sp;
    int quiet = 0;
    for (int i = 0; i + 1 < len; i++) {
        int nx = route[i + 1], d;
        if (nx == s.pos) d = can_extend(L, &s, USE) >= 0 ? USE : NMOVES;
        else
            for (d = 0; d < 4; d++)
                if (L->nb[s.pos][d] == nx && can_extend(L, &s, d) >= 0) break;
        if (d == 4 && nx != s.pos) return 0;
        if (d == NMOVES) return 0;
        if (i >= 1 && d != USE && d != s.prev) P->turns++;
        if (L->gate[nx] >= 0) P->used_gate++;
        if (L->works[nx]) P->used_works++;
        if (L->oneway[nx] >= 0) P->used_oneway++;
        if (L->ice[nx]) P->used_ice++;
        if (L->bridge[nx]) {
            if (seenb & BIT(nx)) P->used_bridge2++;
            seenb |= BIT(nx);
        }
        Events ev = {0};
        State before = s;
        step(L, &s, d, nx, &ev);
        usedm |= BIT(nx);
        quiet++;
        int sp = before.sp;
        for (int e = 0; e < ev.n; e++) {
            if (ev.type[e] == 's') P->swaps++;
            if (ev.type[e] == 'u') {
                // Back from a parking locker. It only counts as using it if something was delivered while
                // it waited (parking one and taking it straight back changes nothing).
                if (before.deliv > parked_at[ev.who[e]]) P->dumps++;
                sp++;
            }
            if (ev.type[e] == 'k') {
                parked_at[ev.who[e]] = s.deliv;
                sp--;
            }
            if (ev.type[e] == 'p') {
                P->pickups++;
                if (sp > 0) P->buried++;
                sp++;
            }
            if (ev.type[e] == 'd') {
                int kk = ev.who[e];
                quiet = 0;
                P->last_doors = 0;
                for (int c = 0; c < L->n; c++)
                    if (L->hroads[kk] & BIT(c)) P->last_doors++;
                if (e == 0 && before.sp > 0) {
                    // Who else could have had it? (Any other open house of that colour, or a locker.)
                    int col = before.stk[before.sp - 1], others = 0;
                    for (int h2 = 0; h2 < L->nh; h2++)
                        if (h2 != kk && before.fill[h2] < L->hord[h2] && (L->hcol[h2] == col || L->hcol[h2] == ANY)) others++;
                    if (others) P->picks++;
                }
                if (passed[kk]) P->late_drops++;
                if (L->hcol[kk] == ANY && e == 0 && sp > 0) {
                    // A locker took it: a "dump" if some house still wanted that colour.
                    int col = before.stk[before.sp - 1];
                    for (int h2 = 0; h2 < L->nh; h2++)
                        if (L->hcol[h2] == col && s.fill[h2] < L->hord[h2]) {
                            P->dumps++;
                            break;
                        }
                }
                sp--;
            }
        }
        if (quiet > P->quiet) P->quiet = quiet;
        for (int a = 0; a < L->nah[nx]; a++) passed[L->ah[nx][a]] = 1;
        if (s.sp > P->max_load) P->max_load = s.sp;
    }
    int used = 0;
    for (int c = 0; c < L->n; c++)
        if (usedm & BIT(c)) used++;
    P->cover = L->nroad ? (double)used / L->nroad : 0;
    return won(L, &s);
}

typedef struct {
    int ok, over;
    long routes, nodes;
    int capped, plans, shortest;
    long nshort;                   // winning routes as short as the shortest (1: the shortest is one of a kind)
    Sub T;                         // the tree, from the start, for the player the level is scored for
    double tries[3], first[3];     // new, regular, expert
    int who;
    Drive D;                       // the likeliest winning line
    int route[MAXR], route_len;
    int kinds, houses, packages, colours, mech_tiles;
    int doors1, doors;             // buildings with a single door; doors in all
    PlanView V;
    double exhaust;
    double difficulty, devious, complexity, fun, melt;
} Report;

static uint64_t plan_hash(const Level *L, const int *route, int len) {
    State s;
    state_init(L, &s);
    uint64_t hsh = 1469598103934665603ULL;
    for (int i = 0; i + 1 < len; i++) {
        int d;
        if (route[i + 1] == s.pos) d = can_extend(L, &s, USE) >= 0 ? USE : NMOVES;
        else
            for (d = 0; d < 4; d++)
                if (L->nb[s.pos][d] == route[i + 1] && can_extend(L, &s, d) >= 0) break;
        if (d == 4 && route[i + 1] != s.pos) return 0;
        if (d == NMOVES) return 0;
        Events ev = {0};
        step(L, &s, d, route[i + 1], &ev);
        for (int e = 0; e < ev.n; e++) {
            hsh = (hsh ^ (uint64_t)ev.type[e]) * 1099511628211ULL;
            hsh = (hsh ^ (uint64_t)(ev.who[e] + 1)) * 1099511628211ULL;
        }
    }
    return hsh;
}

static double sat(double x, double k) {
    return x <= 0 ? 0 : 1.0 - exp(-x / k);
}

static void census(const Level *L, Report *R) {
    int cols[8] = {0};
    R->houses = L->nh;
    R->packages = L->total;
    R->colours = R->kinds = R->mech_tiles = 0;
    for (int k = 0; k < L->nh; k++) cols[L->hcol[k]] = 1;
    for (int c = 0; c < 6; c++) R->colours += cols[c];
    R->doors1 = R->doors = 0;
    for (int k = 0; k < L->nh; k++) {
        int nd = 0;
        for (int c = 0; c < L->n; c++)
            if (L->hroads[k] & BIT(c)) nd++;
        R->doors += nd;
        if (nd == 1) R->doors1++;
    }
    int has[10] = {0};
    for (int c = 0; c < L->n; c++) {
        if (L->oneway[c] >= 0) has[0] = 1, R->mech_tiles++;
        if (L->bridge[c]) has[1] = 1;
        if (L->gate[c] >= 0) has[2] = 1, R->mech_tiles++;
        if (L->hub[c]) has[3] = 1;
        if (L->ice[c]) has[5] = 1, R->mech_tiles++;
        if (L->works[c]) has[7] = 1, R->mech_tiles++;
    }
    if (L->ns) has[4] = 1;
    if (L->ret) has[8] = 1;
    if (L->nl) has[6] = 1;
    for (int k = 0; k < L->nh; k++) {
        if (L->hcol[k] == ANY)
            has[6] = 1;
        else if (L->hord[k] > 1)
            has[9] = 1;
    }
    for (int k = 0; k < 10; k++) R->kinds += has[k];
}

static double clamp01(double x) {
    return x < 0 ? 0 : (x > 1 ? 1 : x);
}

// The scores, 0-10 (design/level_engine.md says what each is for). They're a model's opinion: good for
// comparing levels with each other, not gospel.
//   difficulty  wrong plans an experienced player works through before the answer (4.5 plans = 5, 10 = 8)
//   complexity  how much there is on the board: length, packages, colours, kinds of mechanic, roads
//   devious     difficulty that comes from ideas rather than size (difficulty, marked down for bulk)
//   melt        the mind-melter signature: one answer, the first idea is never right, a lot to work
//               through, near misses, on a small plain board
//   fun         a hypothesis: enough to work through but not a slog, real choices of building, "so close"
//               moments, surprises spread along the drive, a clean board
static void score(const Level *L, Report *R) {
    const Sub *T = &R->T;
    const Drive *P = &R->D;
    const PlanView *V = &R->V;
    R->exhaust = T->leaves > 0 ? T->U / T->leaves : 0;
    double load = 0.05 * P->len + 0.2 * R->packages + 0.7 * R->kinds + 0.25 * (R->colours > 2 ? R->colours - 2 : 0) + 0.03 * L->nroad;
    R->complexity = 10.0 * sat(load, 7.0);
    R->difficulty = 10.0 * sat(V->ptries, 6.5);
    double simple = 1.0 - R->complexity / 10.0;
    R->devious = R->difficulty * (0.55 + 0.75 * simple);
    if (R->devious > 10) R->devious = 10;
    double once = R->routes == 1 ? 1.0 : (R->routes == 2 ? 0.5 : 0.0);
    R->melt = 10.0 * clamp01((0.12 - V->pfirst) / 0.10) * clamp01((V->ptries - 3.0) / 6.0) * once * clamp01((7.5 - R->complexity) / 2.5) *
              (0.5 + 0.5 * clamp01(T->nears / 2.0));
    int third[3] = {0, 0, 0};
    for (int i = 0; i < T->ntw; i++) {
        int q = T->tw[i] * 3 / (P->len + 1);
        third[q > 2 ? 2 : q] = 1;
    }
    double spread = (third[0] + third[1] + third[2]) / 3.0;
    double picks = R->packages > 0 ? (double)P->picks / R->packages : 0;
    R->fun = 10.0 * (0.35 * sat(V->ptries, 4.0) - 0.2 * sat(V->ptries - 18.0, 8.0) + 0.2 * clamp01(picks / 0.5) + 0.15 * clamp01(T->nears / 3.0) +
                     0.15 * spread + 0.15 * sqrt(simple));
    if (R->fun < 0) R->fun = 0;
}

static int g_sol[MAXSOL][MAXR], g_sollen[MAXSOL];

// The full report on a level. budget: how many states the tree walk may look at.
static void report(const Level *L, Report *R, long budget, int who) {
    memset(R, 0, sizeof *R);
    static Solve S;
    memset(&S, 0, sizeof S);
    S.keep = 1;
    S.maxkeep = MAXSOL;
    S.routes = g_sol;
    S.rlen = g_sollen;
    solve(L, &S, 5000, 4000000);
    R->routes = S.count;
    R->nodes = S.nodes;
    R->capped = S.capped;
    R->shortest = S.short_len - 1;
    R->nshort = S.nshort;
    census(L, R);
    if (S.count == 0) return;
    uint64_t seen[MAXSOL];
    int np = 0;
    for (int k = 0; k < S.nkept; k++) {
        uint64_t hsh = plan_hash(L, g_sol[k], g_sollen[k]);
        int dup = 0;
        for (int j = 0; j < np; j++)
            if (seen[j] == hsh) dup = 1;
        if (!dup) seen[np++] = hsh;
    }
    R->plans = np;
    State s0;
    state_init(L, &s0);
    g_over = 0;
    R->who = who;
    for (int p = 0; p < 3; p++) {
        if (p == who) continue;
        set_player(p);
        g_budget = budget;
        Sub t = walk(L, &s0);
        R->tries[p] = t.E;
        R->first[p] = t.F;
    }
    set_player(who);
    g_budget = budget;
    R->T = walk(L, &s0);
    R->tries[who] = R->T.E;
    R->first[who] = R->T.F;
    R->over = g_over;
    if (R->T.wins <= 0) return;
    R->route[0] = L->start;
    memcpy(R->route + 1, g_line[0], sizeof(int) * (size_t)R->T.len);
    R->route_len = R->T.len + 1;
    R->ok = drive(L, R->route, R->route_len, &R->D);
    plan_view(L, &R->V, 3000000);
    score(L, R);
}

static void print_report_json(const Level *L, const Report *R) {
    const Sub *T = &R->T;
    const Drive *P = &R->D;
    printf("{\"id\":\"%s\",\"ok\":%d,\"routes\":%ld,\"answers\":%d,\"nodes\":%ld,\"capped\":%d,\"over\":%d", L->id, R->ok, R->routes, R->plans,
           R->nodes, R->capped, R->over);
    if (R->ok) {
        printf(",\"difficulty\":%.1f,\"devious\":%.1f,\"complexity\":%.1f,\"fun\":%.1f,\"melt\":%.1f", R->difficulty, R->devious, R->complexity,
               R->fun, R->melt);
        printf(",\"who\":%d,\"tries3\":[%.2f,%.2f,%.2f],\"first3\":[%.3f,%.3f,%.3f]", R->who, R->tries[0], R->tries[1], R->tries[2], R->first[0],
               R->first[1], R->first[2]);
        printf(",\"tries\":%.2f,\"first\":%.3f,\"exhaust\":%.2f,\"lines\":%.0f,\"tsum\":%.2f,\"twists\":%d,\"forks\":%d,\"away\":%d,\"gap\":%d,"
               "\"nears\":%d,\"decisions\":%d",
               T->E, T->F, R->exhaust, T->leaves, T->tsum, T->twists, T->forks, T->away, T->gap, T->nears, T->dec);
        printf(",\"pnodes\":%d,\"plans\":%.0f,\"ptries\":%.2f,\"pfirst\":%.3f,\"pdec\":%d,\"ptwists\":%d,\"pdev\":%d,\"pstops\":%d", R->V.pnodes,
               R->V.plans + 1, R->V.ptries, R->V.pfirst, R->V.pdec, R->V.ptwists, R->V.pdev, R->V.pstops);
        printf(",\"opening\":%d,\"picks\":%d,\"buried\":%d,\"doors1\":%d,\"doors\":%d,\"last_doors\":%d", T->opening, P->picks, P->buried, R->doors1,
               R->doors, P->last_doors);
        printf(",\"shortest\":%d,\"nshort\":%ld", R->shortest, R->nshort);
        printf(",\"len\":%d,\"turns\":%d,\"quiet\":%d,\"cover\":%.2f,\"late_drops\":%d,\"dumps\":%d,\"pickups\":%d,\"swaps\":%d,\"max_load\":%d",
               P->len, P->turns, P->quiet, P->cover, P->late_drops, P->dumps, P->pickups, P->swaps, P->max_load);
        printf(",\"used\":{\"gate\":%d,\"works\":%d,\"ice\":%d,\"oneway\":%d,\"bridge\":%d}", P->used_gate, P->used_works, P->used_ice,
               P->used_oneway, P->used_bridge2);
        printf(",\"houses\":%d,\"packages\":%d,\"colours\":%d,\"kinds\":%d,\"mech_tiles\":%d,\"roads\":%d,\"size\":[%d,%d]", R->houses,
               R->packages, R->colours, R->kinds, R->mech_tiles, L->nroad, L->w, L->h);
        printf(",\"where\":[");
        for (int k = 0; k < T->ntw; k++) printf("%s%.2f", k ? "," : "", (double)T->tw[k] / (P->len > 0 ? P->len : 1));
        printf("],\"near_at\":[");
        for (int k = 0; k < T->nnr; k++) printf("%s%.2f", k ? "," : "", (double)T->nr[k] / (P->len > 0 ? P->len : 1));
        printf("],\"route\":[");
        for (int k = 0; k < R->route_len; k++) printf("%s%d", k ? "," : "", R->route[k]);
        printf("]");
    }
    printf("}");
}

static void print_report(const Level *L, const Report *R) {
    print_report_json(L, R);
    printf("\n");
}

// Which player a level is scored for, from where it comes in the game.
static int player_for(const char *id) {
    int n = atoi(id);
    return n <= 0 ? 1 : (n <= 12 ? 0 : (n <= 60 ? 1 : 2));
}

int cmd_score(int argc, char **argv) {
    int who = -1;
    for (int i = 2; i < argc; i++) {
        if (!strncmp(argv[i], "tau=", 4)) TAU = atof(argv[i] + 4);
        if (!strncmp(argv[i], "ptau=", 5)) PTAU = atof(argv[i] + 5);
        if (!strncmp(argv[i], "who=", 4)) who = atoi(argv[i] + 4);
    }
    static char line[8192];
    static Level L;
    static Report R;
    while (fgets(line, sizeof line, stdin)) {
        if (!level_parse(&L, line)) continue;
        if (L.bad || L.has_exit) {
            printf("{\"id\":\"%s\",\"ok\":0,\"skip\":1}\n", L.id);
            continue;
        }
        report(&L, &R, 6000000, who >= 0 ? who : player_for(L.id));
        print_report(&L, &R);
    }
    return 0;
}

// The winning line, junction by junction: what tempts the explorer, and what it costs.
int cmd_explain(int argc, char **argv) {
    int who = -1;
    for (int i = 2; i < argc; i++) {
        if (!strncmp(argv[i], "tau=", 4)) TAU = atof(argv[i] + 4);
        if (!strncmp(argv[i], "who=", 4)) who = atoi(argv[i] + 4);
    }
    static char line[8192];
    static Level L;
    static Report R;
    static const char *DN[4] = {"up", "right", "down", "left"};
    static const char *KN[4] = {"plainly dead", "WINS", "dead (cut off, not obvious)", ""};
    while (fgets(line, sizeof line, stdin)) {
        if (!level_parse(&L, line) || L.bad || L.has_exit) continue;
        report(&L, &R, 6000000, who >= 0 ? who : player_for(L.id));
        printf("== %s: %ld route(s). Tries: new player %.1f, regular %.1f, expert %.1f. For a %s: first-try %.0f%%, %d twist(s), %.0f wrong lines\n",
               L.id, R.routes, R.tries[0], R.tries[1], R.tries[2], R.who == 0 ? "new player" : (R.who == 1 ? "regular" : "expert"), R.T.F * 100,
               R.T.twists, R.T.leaves);
        if (!R.ok) continue;
        State s;
        state_init(&L, &s);
        static int route[MAXR];
        memcpy(route, R.route, sizeof(int) * (size_t)R.route_len);
        int len = R.route_len;
        for (int i = 0; i + 1 < len; i++) {
            Junction J;
            g_budget = 6000000;
            junction(&L, &s, &J);
            int mine = -1;
            for (int j = 0; j < J.nch; j++)
                if (J.cell[j] == route[i + 1]) mine = j;
            if (J.live >= 2) {
                printf("  tile %d at (%d,%d), %d delivered, cost %.2f tries%s\n", i, s.pos % L.w, s.pos / L.w, s.deliv, J.c,
                       J.c >= 0.75 ? "  << TWIST" : (J.c >= 0.3 ? "  < fork" : ""));
                for (int j = 0; j < J.nch; j++) {
                    int d = 0;
                    for (int q = 0; q < 4; q++)
                        if (L.nb[s.pos][q] == J.cell[j]) d = q;
                    const Sub *b = &J.sub[j];
                    if (J.kind[j] == K_PLAIN)
                        printf("      %-5s plainly dead\n", DN[d]);
                    else if (b->wins > 0)
                        printf("      %-5s %s next delivery in %d, pull %.2f%s\n", DN[d], j == mine ? "THE ROUTE:" : "also wins:", J.att[j], J.w[j],
                               J.kind[j] == K_WIN ? " (wins here)" : "");
                    else
                        printf("      %-5s trap: next delivery in %d, pull %.2f, tried first %.0f%%, %.0f wrong line(s), gets to %d of %d, costs %.2f %s\n",
                               DN[d], J.att[j], J.w[j], J.p[j] * 100, b->leaves, b->reach, L.total, J.p[j] * J.de[j], KN[J.kind[j] == K_LEAF ? 2 : 3]);
                }
            }
            if (mine < 0) break;
            s = J.t[mine];
        }
    }
    return 0;
}

#include "gen.c"
