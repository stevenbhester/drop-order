// gen.c: the level generator (part of lm.c; see there).
//
// HOW IT WORKS. Pick a small town and a drive through it (the answer). Put buildings along the drive and
// work out the starting load that makes the drive win. That level is far too easy: lots of other drives win
// too. Then SEARCH: make thousands of small edits (recolour a house, move it, change which pass delivers to
// it, add a door, add a pickup, drop in an arrow...), each time re-deriving the load so the drive still
// wins, and keep the edits that take the level towards what the slot asks for: few winning routes, the
// right number of failed tries for the player it's meant for, twists spread along the way, convincing
// near misses. It's simulated annealing: early on it accepts some edits that make things worse, so it
// doesn't get stuck on the first half-decent level.
//
// The answer itself never changes during the search, so every level it visits is solvable by construction.

// ------------------------------------------------------------------ random numbers

static uint64_t g_rng = 88172645463325252ULL;

static inline uint64_t rnd64(void) {
    g_rng ^= g_rng << 13;
    g_rng ^= g_rng >> 7;
    g_rng ^= g_rng << 17;
    return g_rng;
}
static inline int rint_(int n) {
    return n <= 0 ? 0 : (int)(rnd64() % (uint64_t)n);
}
static inline double rflt(void) {
    return (double)(rnd64() >> 11) / 9007199254740992.0;
}
static inline int rrange(int lo, int hi) {
    return hi <= lo ? lo : lo + rint_(hi - lo + 1);
}

// ------------------------------------------------------------------ what a slot asks for

enum { M_ONEWAY, M_BRIDGE, M_GATE, M_HUB, M_PICK, M_ICE, M_LOCK, M_WORKS, M_RET, M_MULTI, M_WH, NKIND };
static const char *KIND_NAME[NKIND] = {"oneway", "bridge", "gate", "hub", "pickup", "ice", "locker", "works", "return", "multi", "warehouse"};

enum { F_NONE, F_DECOY, F_LONGWAY, F_TWODOOR, F_LONGCON, F_GAUNTLET, F_KNOT, F_DUMP, F_RESTOCK, F_SORTER, F_TWIN, F_HOARD, F_BREATHER, NFLAVOR };
static const char *FLAVOR_NAME[NFLAVOR] = {"none", "decoy", "longway", "twodoor", "longcon", "gauntlet", "knot", "dump", "restock", "sorter", "twin", "hoard", "breather"};

typedef struct {
    int slot, seed, w, h, ret, who, keep, gift, flavor, melter, late, verbose;
    double secs;
    int hmin, hmax, ncol, colmin, pkmin, pkmax, maxorder;
    int smin, smax, stock, lmin, lmax;
    int amax, imax, gmax, wmax, umax, bmax;
    int need[NKIND];
    double elo, ehi, fmax, cover_min, pelo, pehi, pfmax, mono;
    int pnmin, pnmax, pwmin, open_end, d1max, d1min, pickmin, fuel;
    int rmin, rmax, twmin, nearmin, nodes_max, len_min, len_max, turns_max, steps, qmax, spread;
} Slot;

static void slot_defaults(Slot *S) {
    memset(S, 0, sizeof *S);
    S->seed = 1;
    S->w = 6;
    S->h = 8;
    S->who = 1;
    S->keep = 3;
    S->secs = 20;
    S->hmin = 4;
    S->hmax = 6;
    S->ncol = 3;
    S->colmin = 2;
    S->pkmin = 4;
    S->pkmax = 8;
    S->maxorder = 1;
    S->elo = 2;
    S->ehi = 4;
    S->fmax = 0.2;
    S->pfmax = 1.0;
    S->d1max = -1;
    S->pehi = 1e9;
    S->cover_min = 0.6;
    S->rmin = 1;
    S->rmax = 2;
    S->twmin = 2;
    S->nodes_max = 2000;
    S->len_min = 12;
    S->steps = 0;
}

static void slot_arg(Slot *S, const char *a) {
    const char *eq = strchr(a, '=');
    if (!eq) return;
    char key[32];
    size_t n = (size_t)(eq - a);
    if (n >= sizeof key) return;
    memcpy(key, a, n);
    key[n] = 0;
    const char *v = eq + 1;
#define INT(name)                         \
    if (!strcmp(key, #name)) {            \
        S->name = atoi(v);                \
        return;                           \
    }
#define DBL(name)                         \
    if (!strcmp(key, #name)) {            \
        S->name = atof(v);                \
        return;                           \
    }
    INT(slot) INT(seed) INT(w) INT(h) INT(ret) INT(who) INT(keep) INT(gift) INT(melter) INT(late) INT(verbose)
    INT(hmin) INT(hmax) INT(ncol) INT(colmin) INT(pkmin) INT(pkmax) INT(maxorder) INT(smin) INT(smax) INT(stock) INT(lmin) INT(lmax)
    INT(amax) INT(imax) INT(gmax) INT(wmax) INT(umax) INT(bmax) INT(rmin) INT(rmax) INT(twmin) INT(nearmin) INT(nodes_max)
    INT(len_min) INT(len_max) INT(turns_max) INT(steps) INT(qmax) INT(spread)
    DBL(secs) DBL(elo) DBL(ehi) DBL(fmax) DBL(cover_min) DBL(pelo) DBL(pehi) DBL(pfmax) DBL(mono) INT(pnmin) INT(pnmax) INT(pwmin) INT(open_end) INT(d1max) INT(d1min) INT(pickmin) INT(fuel)
#undef INT
#undef DBL
    if (!strcmp(key, "flavor")) {
        for (int f = 0; f < NFLAVOR; f++)
            if (!strcmp(v, FLAVOR_NAME[f])) S->flavor = f;
        return;
    }
    if (!strcmp(key, "need")) {
        for (int k = 0; k < NKIND; k++) {
            const char *p = strstr(v, KIND_NAME[k]);
            if (p) S->need[k] = 1;
        }
        return;
    }
    if (!strcmp(key, "tau")) TAU = atof(v);
}

// ------------------------------------------------------------------ a design: a town, the answer, the buildings

typedef struct {
    int cell, kind;        // kind: 0 house, 1 locker, 2 pickup
    int col, n;            // colour; packages wanted (or held)
    uint8_t pass[5];       // per package: which time the answer drives past delivers it (0 = the first)
    uint8_t feed[5];       // lockers: the colour each package is, when it comes from the starting load
} Bld;

typedef struct {
    int w, h, ret;
    uint8_t road[MAXC], bridge[MAXC], hub[MAXC], ice[MAXC], works[MAXC];
    int8_t oneway[MAXC], gate[MAXC];
    int nroute, route[MAXR];
    int16_t at[MAXC];      // where on the answer each tile is first driven (-1: never)
    int nb;
    Bld b[MAXB];
} Design;

static int dir_between(const Design *D, int a, int b) {
    int d = b - a;
    if (d == -D->w) return 0;
    if (d == 1) return 1;
    if (d == D->w) return 2;
    if (d == -1) return 3;
    return -1;
}

static int cell_step(const Design *D, int c, int d) {
    int x = c % D->w + DX[d], y = c / D->w + DY[d];
    return (x < 0 || y < 0 || x >= D->w || y >= D->h) ? -1 : y * D->w + x;
}

static int road_degree(const Design *D, int c) {
    int n = 0;
    for (int d = 0; d < 4; d++) {
        int q = cell_step(D, c, d);
        if (q >= 0 && D->road[q]) n++;
    }
    return n;
}

static int plain_tile(const Design *D, int c) {
    return D->road[c] && !D->bridge[c] && !D->hub[c] && !D->ice[c] && !D->works[c] && D->oneway[c] < 0 && D->gate[c] < 0;
}

// A straight piece of road with nothing joining it (where a gate or roadworks can stand).
static int straight2(const Design *D, int c) {
    int r[4];
    for (int d = 0; d < 4; d++) {
        int q = cell_step(D, c, d);
        r[d] = q >= 0 && D->road[q];
    }
    return (r[0] && r[2] && !r[1] && !r[3]) || (r[1] && r[3] && !r[0] && !r[2]);
}

static int building_at(const Design *D, int c) {
    for (int i = 0; i < D->nb; i++)
        if (D->b[i].cell == c) return i;
    return -1;
}

static int count_kind(const Design *D, int kind) {
    int n = 0;
    for (int i = 0; i < D->nb; i++)
        if (D->b[i].kind == kind) n++;
    return n;
}

// Could a building stand here? Not on road, touching the answer somewhere, and not touching the start, a
// bridge or a hub (the game's own rules).
static int building_spot(const Design *D, int c) {
    if (D->road[c] || building_at(D, c) >= 0) return 0;
    int on = 0;
    for (int d = 0; d < 4; d++) {
        int q = cell_step(D, c, d);
        if (q < 0 || !D->road[q]) continue;
        if (q == D->route[0] || D->bridge[q] || D->hub[q]) return 0;
        if (D->at[q] >= 1) on = 1;
    }
    return on;
}

// ------------------------------------------------------------------ design -> level

static int all_roads_joined(const Level *L) {
    u128 r = BIT(L->start);
    for (;;) {
        u128 n = (r | ((r & ~L->colR) << 1) | ((r & ~L->colL) >> 1) | (r << L->w) | (r >> L->w)) & L->roadm;
        if (n == r) break;
        r = n;
    }
    return r == L->roadm;
}

// The loader's rules (scripts/level_data.gd), plus the house style: no 2x2 blocks of road, arrows point at
// road, gates and roadworks on a straight piece, every road joined up.
static int level_valid(const Level *L) {
    int s = L->start;
    if (L->bridge[s] || L->hub[s] || L->ice[s] || L->works[s] || L->oneway[s] >= 0 || L->gate[s] >= 0) return 0;
    if (L->nah[s] || L->nas[s]) return 0;
    for (int k = 0; k < L->nh; k++)
        if (!L->hroads[k]) return 0;
    for (int k = 0; k < L->ns; k++)
        if (!L->sroads[k]) return 0;
    for (int c = 0; c < L->n; c++) {
        if (!L->road[c]) continue;
        int r[4], deg = 0;
        for (int d = 0; d < 4; d++) {
            int q = L->nb[c][d];
            r[d] = q >= 0 && L->road[q];
            deg += r[d];
        }
        if ((L->bridge[c] || L->hub[c]) && (L->nah[c] || L->nas[c])) return 0;
        if (L->bridge[c] && deg != 4) return 0;
        if (L->oneway[c] >= 0 && !r[L->oneway[c]]) return 0;
        if ((L->gate[c] >= 0 || L->works[c]) && !((r[0] && r[2] && !r[1] && !r[3]) || (r[1] && r[3] && !r[0] && !r[2]))) return 0;
        int x = c % L->w, y = c / L->w;
        if (x + 1 < L->w && y + 1 < L->h && L->road[c + 1] && L->road[c + L->w] && L->road[c + L->w + 1]) return 0;
    }
    return all_roads_joined(L);
}

// Builds the level a design stands for: lays out the buildings, works out the starting load that makes
// the answer win, and checks with the real rules that it does. 0 if the design doesn't work.
// eff: how many tiles of the answer it takes to win (the rest is road the player needn't drive).
static int build_level(const Design *D, Level *L, int *eff) {
    level_clear(L, D->w, D->h);
    snprintf(L->id, sizeof L->id, "gen");
    memcpy(L->road, D->road, sizeof L->road);
    memcpy(L->bridge, D->bridge, sizeof L->bridge);
    memcpy(L->hub, D->hub, sizeof L->hub);
    memcpy(L->ice, D->ice, sizeof L->ice);
    memcpy(L->works, D->works, sizeof L->works);
    memcpy(L->oneway, D->oneway, sizeof L->oneway);
    memcpy(L->gate, D->gate, sizeof L->gate);
    L->start = D->route[0];
    L->ret = D->ret;
    // Buildings in map order, as the loader meets them.
    int ord[MAXB], dh[MAXB];
    for (int i = 0; i < D->nb; i++) ord[i] = i;
    for (int i = 1; i < D->nb; i++)
        for (int j = i; j > 0 && D->b[ord[j]].cell < D->b[ord[j - 1]].cell; j--) {
            int t = ord[j];
            ord[j] = ord[j - 1];
            ord[j - 1] = t;
        }
    int pickups = 0;
    for (int i = 0; i < D->nb; i++) {
        const Bld *b = &D->b[ord[i]];
        if (b->kind == 2) {
            L->scell[L->ns] = b->cell;
            L->scol[L->ns] = b->col;
            L->scnt[L->ns++] = b->n;
            pickups += b->n;
        } else {
            dh[L->nh] = ord[i];
            L->hcell[L->nh] = b->cell;
            L->hcol[L->nh] = b->kind == 1 ? ANY : b->col;
            L->hord[L->nh++] = b->n;
        }
    }
    level_finish(L);
    if (!level_valid(L)) return 0;
    int n0 = L->total - pickups;
    if (n0 < 0 || n0 > 12 || L->total < 1) return 0;
    for (int c = 0; c < L->n; c++)
        if (L->works[c] && D->at[c] < 0) {          // roadworks off the answer: any count that can be reached
            if (L->total < 2) return 0;
            if (L->works[c] > L->total - 1) L->works[c] = (uint8_t)(L->total - 1);
        }

    // Which pass delivers what.
    uint8_t plan[MAXB][5];
    memset(plan, 0, sizeof plan);
    for (int k = 0; k < L->nh; k++) {
        int np = 0;
        for (int i = 1; i < D->nroute; i++)
            if (L->hroads[k] & BIT(D->route[i])) np++;
        if (np == 0) return 0;
        if (np > 5) np = 5;
        const Bld *b = &D->b[dh[k]];
        for (int u = 0; u < b->n && u < 5; u++) plan[k][b->pass[u] < np ? b->pass[u] : np - 1]++;
    }
    // Drive the answer with a load we don't know yet: each delivery that comes off the starting load
    // settles what colour that package must have been.
    int sym[MAXSTK + 8], sp = n0, varcol[16];
    for (int j = 0; j < n0; j++) sym[j] = -(n0 - j);       // bottom ... top = variables n0-1 ... 0
    for (int j = 0; j < 16; j++) varcol[j] = -1;
    uint8_t seenp[MAXB] = {0}, picked[MAXB] = {0}, unitc[MAXB] = {0};
    for (int i = 1; i < D->nroute; i++) {
        int t = D->route[i];
        if (L->hub[t] && sp >= 2) {
            int a = sym[sp - 1];
            sym[sp - 1] = sym[sp - 2];
            sym[sp - 2] = a;
        }
        for (int any = 0; any < 2; any++)
            for (int a = 0; a < L->nah[t]; a++) {
                int k = L->ah[t][a];
                if ((L->hcol[k] == ANY) != any) continue;
                for (int m = plan[k][seenp[k] < 5 ? seenp[k] : 4]; seenp[k] < 5 && m > 0; m--) {
                    if (sp == 0) return 0;
                    int v = sym[sp - 1];
                    if (v >= 0) {
                        if (!any && v != L->hcol[k]) return 0;
                    } else {
                        varcol[-v - 1] = any ? D->b[dh[k]].feed[unitc[k] < 5 ? unitc[k] : 4] : L->hcol[k];
                    }
                    sp--;
                    unitc[k]++;
                }
            }
        for (int a = 0; a < L->nah[t]; a++) seenp[L->ah[t][a]]++;
        for (int a = 0; a < L->nas[t]; a++) {
            int k = L->as_[t][a];
            if (picked[k]) continue;
            picked[k] = 1;
            for (int q = 0; q < L->scnt[k]; q++) {
                if (sp >= MAXSTK) return 0;
                sym[sp++] = L->scol[k];
            }
        }
    }
    if (sp != 0) return 0;
    for (int j = 0; j < n0; j++)
        if (varcol[j] < 0 || varcol[j] > 5) return 0;
    L->nstack = n0;
    for (int j = 0; j < n0; j++) L->stack0[j] = (uint8_t)varcol[n0 - 1 - j];

    // Now for real. Gates and roadworks on the answer take whatever lets it through.
    State s;
    state_init(L, &s);
    int most = s.sp;
    for (int i = 1; i < D->nroute; i++) {
        int t = D->route[i], d = dir_between(D, s.pos, t);
        if (d < 0) return 0;
        if (D->gate[t] >= 0) {
            if (s.sp == 0) return 0;
            L->gate[t] = (int8_t)s.stk[s.sp - 1];
        }
        if (D->works[t]) {
            if (s.deliv < 1) return 0;
            L->works[t] = (uint8_t)(D->works[t] < s.deliv ? D->works[t] : s.deliv);
        }
        if (can_extend(L, &s, d) != t) return 0;
        step(L, &s, d, t, NULL);
        if (s.sp > most) most = s.sp;
        if (won(L, &s)) {
            *eff = i + 1;
            return most <= 12;
        }
    }
    return 0;
}

// ------------------------------------------------------------------ a town and a drive

static int flood_count(const Design *D, int from) {
    static int q[MAXC];
    static uint8_t seen[MAXC];
    memset(seen, 0, sizeof seen);
    int head = 0, tail = 0, n = 0;
    q[tail++] = from;
    seen[from] = 1;
    while (head < tail) {
        int c = q[head++];
        n++;
        for (int d = 0; d < 4; d++) {
            int nx = cell_step(D, c, d);
            if (nx >= 0 && D->road[nx] && !seen[nx]) {
                seen[nx] = 1;
                q[tail++] = nx;
            }
        }
    }
    return n;
}

static int count_roads(const Design *D) {
    int n = 0;
    for (int c = 0; c < D->w * D->h; c++) n += D->road[c];
    return n;
}

// Streets on a lattice two or three apart (so no fat blocks of road), with some stretches taken out.
static int make_map(Design *D, const Slot *S) {
    int w = S->w, h = S->h;
    memset(D, 0, sizeof *D);
    D->w = w;
    D->h = h;
    D->ret = S->ret;
    for (int c = 0; c < MAXC; c++) {
        D->oneway[c] = D->gate[c] = -1;
        D->at[c] = -1;
    }
    int xs[10], nx = 0, ys[12], ny = 0;
    for (int x = rint_(2); x < w && nx < 10; x += 2 + (rint_(100) < 40)) xs[nx++] = x;
    for (int y = rint_(2); y < h && ny < 12; y += 2 + (rint_(100) < 40)) ys[ny++] = y;
    if (nx < 2 || ny < 2) return 0;
    for (int j = 0; j < ny; j++)
        for (int x = xs[0]; x <= xs[nx - 1]; x++) D->road[ys[j] * w + x] = 1;
    for (int i = 0; i < nx; i++)
        for (int y = ys[0]; y <= ys[ny - 1]; y++) D->road[y * w + xs[i]] = 1;
    // The stretches between crossroads: (cell, direction, length).
    int ec[160], ed[160], el[160], ne = 0;
    for (int j = 0; j < ny; j++)
        for (int i = 0; i + 1 < nx; i++) {
            ec[ne] = ys[j] * w + xs[i] + 1;
            ed[ne] = 1;
            el[ne++] = xs[i + 1] - xs[i] - 1;
        }
    for (int i = 0; i < nx; i++)
        for (int j = 0; j + 1 < ny; j++) {
            ec[ne] = (ys[j] + 1) * w + xs[i];
            ed[ne] = 2;
            el[ne++] = ys[j + 1] - ys[j] - 1;
        }
    for (int i = ne - 1; i > 0; i--) {
        int j = rint_(i + 1), t;
        t = ec[i], ec[i] = ec[j], ec[j] = t;
        t = ed[i], ed[i] = ed[j], ed[j] = t;
        t = el[i], el[i] = el[j], el[j] = t;
    }
    int cut = (int)(ne * (0.05 + 0.3 * rflt()));
    for (int e = 0; e < ne && cut > 0; e++) {
        int stepc = ed[e] == 1 ? 1 : w;
        for (int q = 0; q < el[e]; q++) D->road[ec[e] + q * stepc] = 0;
        // Sometimes leave a stub: a short dead end where the street used to go.
        if (el[e] >= 1 && rint_(100) < 30) D->road[ec[e] + (rint_(2) ? 0 : (el[e] - 1) * stepc)] = 1;
        int any = -1;
        for (int c = 0; c < w * h && any < 0; c++)
            if (D->road[c]) any = c;
        if (any < 0 || flood_count(D, any) != count_roads(D)) {
            for (int q = 0; q < el[e]; q++) D->road[ec[e] + q * stepc] = 1;
            continue;
        }
        cut--;
    }
    // Crossroads left with a single street are just bends in a dead end: trim lone tiles nobody can use.
    for (int pass = 0; pass < 3; pass++)
        for (int c = 0; c < w * h; c++)
            if (D->road[c] && road_degree(D, c) == 0) D->road[c] = 0;
    if (count_roads(D) < 10) return 0;
    // Bridges, where the slot has them: a crossroads with all four streets.
    int nbr = S->bmax > 0 ? rrange(S->need[M_BRIDGE] ? 1 : 0, S->bmax) : 0;
    for (int tries = 0; tries < 40 && nbr > 0; tries++) {
        int c = rint_(w * h);
        if (!D->road[c] || D->bridge[c] || road_degree(D, c) != 4) continue;
        int near = 0;
        for (int d = 0; d < 4; d++) near += D->bridge[cell_step(D, c, d)];
        if (near) continue;
        D->bridge[c] = 1;
        nbr--;
    }
    return 1;
}

static const Level *g_wl;
static long g_wbudget;
static int g_wtarget, g_wbridge, g_wroute[MAXR], g_wlen;

static int walk_route(const State *s) {
    if (g_wbudget-- <= 0) return 0;
    const Level *L = g_wl;
    if (!L->ret && s->len - 1 >= g_wtarget) {
        g_wlen = s->len;
        return 1;
    }
    int nx[4], score[4], n = 0, dd[4];
    for (int d = 0; d < 4; d++) {
        int c = can_extend(L, s, d);
        if (c < 0) continue;
        if (L->ret && c == L->start) {
            if (s->len < g_wtarget) continue;        // home too soon
            g_wroute[s->len] = c;
            g_wlen = s->len + 1;
            return 1;
        }
        // Fewest ways on first (it fills the town instead of cutting it in half), with plenty of noise.
        int onward = 0;
        for (int e = 0; e < 4; e++) {
            int q = L->nb[c][e];
            if (q >= 0 && L->road[q] && !(s->vis & BIT(q)) && q != s->pos) onward++;
        }
        nx[n] = c;
        dd[n] = d;
        score[n++] = onward * 10 + rint_(25) - (d == s->prev ? 4 : 0);
    }
    for (int i = 1; i < n; i++)
        for (int j = i; j > 0 && score[j] < score[j - 1]; j--) {
            int t;
            t = score[j], score[j] = score[j - 1], score[j - 1] = t;
            t = nx[j], nx[j] = nx[j - 1], nx[j - 1] = t;
            t = dd[j], dd[j] = dd[j - 1], dd[j - 1] = t;
        }
    for (int i = 0; i < n; i++) {
        State t = *s;
        step(L, &t, dd[i], nx[i], NULL);
        g_wroute[t.len - 1] = nx[i];
        if (walk_route(&t)) return 1;
    }
    return 0;
}

// The answer: a drive from a start tile that uses most of the town.
static int make_route(Design *D, const Slot *S) {
    static Level L;
    int n = D->w * D->h, nroad = count_roads(D);
    for (int tries = 0; tries < 30; tries++) {
        int st = rint_(n);
        if (!D->road[st] || D->bridge[st] || road_degree(D, st) < (D->ret ? 2 : 1)) continue;
        level_clear(&L, D->w, D->h);
        memcpy(L.road, D->road, sizeof L.road);
        memcpy(L.bridge, D->bridge, sizeof L.bridge);
        L.start = st;
        L.ret = D->ret;
        level_finish(&L);
        double cover = S->cover_min + 0.08 + rflt() * (0.97 - S->cover_min - 0.08);
        g_wtarget = (int)(cover * nroad);
        if (g_wtarget < S->len_min) g_wtarget = S->len_min;
        if (S->len_max && g_wtarget > S->len_max) g_wtarget = S->len_max;
        if (g_wtarget > nroad - 1) g_wtarget = nroad - 1;
        g_wl = &L;
        g_wbudget = 20000;
        State s;
        state_init(&L, &s);
        g_wroute[0] = st;
        g_wlen = 0;
        if (!walk_route(&s)) continue;
        D->nroute = g_wlen;
        memcpy(D->route, g_wroute, sizeof(int) * (size_t)g_wlen);
        for (int c = 0; c < MAXC; c++) D->at[c] = -1;
        for (int i = g_wlen - 1; i >= 0; i--) D->at[D->route[i]] = (int16_t)i;
        if (S->need[M_BRIDGE]) {        // a bridge level has to cross one twice
            int twice = 0;
            for (int i = 0; i < g_wlen; i++)
                if (D->bridge[D->route[i]] && D->at[D->route[i]] != i) twice = 1;
            if (!twice) continue;
        }
        return 1;
    }
    return 0;
}

static int random_spot(const Design *D) {
    int n = D->w * D->h;
    for (int tries = 0; tries < 60; tries++) {
        int c = rint_(n);
        if (building_spot(D, c)) return c;
    }
    return -1;
}

static void new_building(Bld *b, int cell, int kind, int col, int n) {
    memset(b, 0, sizeof *b);
    b->cell = cell;
    b->kind = kind;
    b->col = col;
    b->n = n;
    for (int u = 0; u < 5; u++) {
        b->pass[u] = (uint8_t)(rint_(100) < 55 ? 0 : rint_(3));
        b->feed[u] = (uint8_t)rint_(6);
    }
}

static int add_building(Design *D, int kind, int col, int n) {
    if (D->nb >= MAXB - 1) return 0;
    int c = random_spot(D);
    if (c < 0) return 0;
    new_building(&D->b[D->nb++], c, kind, col, n);
    return 1;
}

// A first, far-too-easy level: houses, pickups and lockers scattered along the answer.
static int first_buildings(Design *D, const Slot *S) {
    D->nb = 0;
    int nh = rrange(S->hmin, S->hmax), ns = rrange(S->smin, S->smax), nl = rrange(S->lmin, S->lmax);
    for (int i = 0; i < nh; i++) {
        int n = (S->maxorder > 1 && rint_(100) < 35) ? rrange(2, S->maxorder) : 1;
        if (!add_building(D, 0, rint_(S->ncol), n)) return 0;
    }
    for (int i = 0; i < nl; i++)
        if (!add_building(D, 1, 0, 1)) return 0;
    for (int i = 0; i < ns; i++)
        if (!add_building(D, 2, rint_(S->ncol), S->stock > 1 ? rrange(2, S->stock) : 1)) return 0;
    for (int i = 0; i < D->nb; i++)
        for (int u = 0; u < 5; u++) D->b[i].feed[u] = (uint8_t)rint_(S->ncol);
    return 1;
}

// ------------------------------------------------------------------ edits

static int count_tiles(const Design *D, int which) {
    int n = 0;
    for (int c = 0; c < D->w * D->h; c++) {
        if (which == M_ONEWAY) n += D->oneway[c] >= 0;
        if (which == M_ICE) n += D->ice[c];
        if (which == M_GATE) n += D->gate[c] >= 0;
        if (which == M_WORKS) n += D->works[c] != 0;
        if (which == M_HUB) n += D->hub[c];
    }
    return n;
}

static int random_road(const Design *D) {
    int n = D->w * D->h;
    for (int tries = 0; tries < 40; tries++) {
        int c = rint_(n);
        if (D->road[c] && c != D->route[0]) return c;
    }
    return -1;
}

static int touches_building(const Design *D, int c) {
    for (int d = 0; d < 4; d++) {
        int q = cell_step(D, c, d);
        if (q >= 0 && building_at(D, q) >= 0) return 1;
    }
    return 0;
}

// One small change. 0 if the one picked can't be made here (the caller just tries again).
static int mutate(Design *D, const Slot *S) {
    int n = D->w * D->h;
    int r = rint_(100);
    int nh = count_kind(D, 0), ns = count_kind(D, 2), nl = count_kind(D, 1);
    if (r < 18) {                       // recolour a house or a pickup
        if (D->nb == 0 || S->ncol < 2) return 0;
        Bld *b = &D->b[rint_(D->nb)];
        if (b->kind == 1) {
            b->feed[rint_(b->n)] = (uint8_t)rint_(S->ncol);
            return 1;
        }
        int c = rint_(S->ncol);
        if (c == b->col) return 0;
        b->col = c;
        return 1;
    }
    if (r < 26) {                       // two buildings swap colours
        if (D->nb < 2) return 0;
        Bld *a = &D->b[rint_(D->nb)], *b = &D->b[rint_(D->nb)];
        if (a == b || a->kind == 1 || b->kind == 1 || a->col == b->col) return 0;
        int t = a->col;
        a->col = b->col;
        b->col = t;
        return 1;
    }
    if (r < 40) {                       // deliver on a different pass
        if (D->nb == 0) return 0;
        Bld *b = &D->b[rint_(D->nb)];
        if (b->kind == 2) return 0;
        b->pass[rint_(b->n)] = (uint8_t)rint_(3);
        return 1;
    }
    if (r < 52) {                       // move a building
        if (D->nb == 0) return 0;
        int i = rint_(D->nb), old = D->b[i].cell;
        D->b[i].cell = -1;
        int c = random_spot(D);
        if (c < 0) {
            D->b[i].cell = old;
            return 0;
        }
        D->b[i].cell = c;
        return 1;
    }
    if (r < 58) {                       // another house
        if (nh >= S->hmax) return 0;
        return add_building(D, 0, rint_(S->ncol), 1);
    }
    if (r < 64) {                       // one fewer building
        if (D->nb == 0) return 0;
        int i = rint_(D->nb);
        const Bld *b = &D->b[i];
        if (b->kind == 0 && nh <= S->hmin) return 0;
        if (b->kind == 2 && ns <= S->smin) return 0;
        if (b->kind == 1 && nl <= S->lmin) return 0;
        D->b[i] = D->b[--D->nb];
        return 1;
    }
    if (r < 68) {                       // a pickup
        if (ns >= S->smax) return 0;
        return add_building(D, 2, rint_(S->ncol), S->stock > 1 ? rrange(2, S->stock) : 1);
    }
    if (r < 71) {                       // a locker, or a house turns into one (or back)
        if (S->lmax == 0 || D->nb == 0) return 0;
        if (nl < S->lmax && rint_(2)) return add_building(D, 1, 0, 1);
        Bld *b = &D->b[rint_(D->nb)];
        if (b->kind == 0 && nl < S->lmax && nh > S->hmin) {
            b->kind = 1;
            return 1;
        }
        if (b->kind == 1 && nl > S->lmin && nh < S->hmax) {
            b->kind = 0;
            b->col = rint_(S->ncol);
            return 1;
        }
        return 0;
    }
    if (r < 75) {                       // a bigger or smaller order (or warehouse)
        if (D->nb == 0) return 0;
        Bld *b = &D->b[rint_(D->nb)];
        int top = b->kind == 2 ? S->stock : S->maxorder;
        if (top < 2) return 0;
        int v = b->n + (rint_(2) ? 1 : -1);
        if (v < 1 || v > top || v > 5) return 0;
        b->n = v;
        return 1;
    }
    if (r < 83) {                       // a new piece of road: a door, a shortcut, a dead end
        int c = rint_(n);
        if (D->road[c] || building_at(D, c) >= 0) return 0;
        int touch = 0;
        for (int d = 0; d < 4; d++) {
            int q = cell_step(D, c, d);
            if (q >= 0 && D->road[q]) touch = 1;
        }
        if (!touch) return 0;
        D->road[c] = 1;
        return 1;
    }
    if (r < 89) {                       // take a piece of road away (never the answer's)
        int c = random_road(D);
        if (c < 0 || D->at[c] >= 0 || D->bridge[c]) return 0;
        D->road[c] = 0;
        D->hub[c] = D->ice[c] = D->works[c] = 0;
        D->oneway[c] = D->gate[c] = -1;
        return 1;
    }
    // The slot's own mechanics.
    int kinds[5], nk = 0;
    if (S->amax) kinds[nk++] = M_ONEWAY;
    if (S->imax) kinds[nk++] = M_ICE;
    if (S->gmax) kinds[nk++] = M_GATE;
    if (S->wmax) kinds[nk++] = M_WORKS;
    if (S->umax) kinds[nk++] = M_HUB;
    if (nk == 0) return 0;
    int kind = kinds[rint_(nk)];
    int c = random_road(D);
    if (c < 0 || D->bridge[c]) return 0;
    int i = D->at[c];
    int din = i >= 1 ? dir_between(D, D->route[i - 1], c) : -1;
    int dout = (i >= 0 && i + 1 < D->nroute) ? dir_between(D, c, D->route[i + 1]) : -1;
    if (kind == M_ONEWAY) {
        if (D->oneway[c] >= 0) {
            D->oneway[c] = -1;
            return 1;
        }
        if (!plain_tile(D, c) || count_tiles(D, M_ONEWAY) >= S->amax) return 0;
        int d = dout >= 0 ? dout : rint_(4);
        int q = cell_step(D, c, d);
        if (q < 0 || !D->road[q]) return 0;
        D->oneway[c] = (int8_t)d;
        return 1;
    }
    if (kind == M_ICE) {
        if (D->ice[c]) {
            D->ice[c] = 0;
            return 1;
        }
        if (!plain_tile(D, c) || count_tiles(D, M_ICE) >= S->imax) return 0;
        if (i >= 0 && din >= 0 && dout >= 0 && din != dout) return 0;        // the answer turns here
        D->ice[c] = 1;
        return 1;
    }
    if (kind == M_GATE) {
        if (D->gate[c] >= 0) {
            D->gate[c] = -1;
            return 1;
        }
        if (!plain_tile(D, c) || !straight2(D, c) || count_tiles(D, M_GATE) >= S->gmax) return 0;
        D->gate[c] = (int8_t)rint_(S->ncol);
        return 1;
    }
    if (kind == M_WORKS) {
        if (D->works[c]) {
            D->works[c] = 0;
            return 1;
        }
        if (!plain_tile(D, c) || !straight2(D, c) || count_tiles(D, M_WORKS) >= S->wmax) return 0;
        D->works[c] = (uint8_t)rrange(1, 4);
        return 1;
    }
    if (D->hub[c]) {
        D->hub[c] = 0;
        return 1;
    }
    if (!plain_tile(D, c) || touches_building(D, c) || count_tiles(D, M_HUB) >= S->umax) return 0;
    D->hub[c] = 1;
    return 1;
}

// ------------------------------------------------------------------ how well does a level fit its slot?

typedef struct {
    double fit;
    int eff, flavor_ok, need_ok;
    long nshort;          // winning routes as short as the shortest (for fuel: the tank holds that much)
    Report R;
} Eval;

static void strip_kind(Level *L, int kind) {
    for (int c = 0; c < L->n; c++) {
        if (kind == M_ONEWAY) L->oneway[c] = -1;
        if (kind == M_BRIDGE) L->bridge[c] = 0;
        if (kind == M_GATE) L->gate[c] = -1;
        if (kind == M_HUB) L->hub[c] = 0;
        if (kind == M_ICE) L->ice[c] = 0;
        if (kind == M_WORKS) L->works[c] = 0;
    }
    if (kind == M_RET) L->ret = 0;
    level_finish(L);
}

// Is this mechanic doing something? On the answer's road, and the set of winning routes changes without it.
static int kind_matters(const Level *L, const Report *R, int kind) {
    const Drive *P = &R->D;
    if (kind == M_PICK) return P->pickups >= 1 && P->buried >= 1;
    if (kind == M_MULTI) {
        for (int k = 0; k < L->nh; k++)
            if (L->hcol[k] != ANY && L->hord[k] > 1) return 1;
        return 0;
    }
    if (kind == M_WH) {
        for (int k = 0; k < L->ns; k++)
            if (L->scnt[k] >= 3) return 1;
        return 0;
    }
    if (kind == M_LOCK) {
        for (int k = 0; k < L->nh; k++)
            if (L->hcol[k] == ANY) return 1;
        return 0;
    }
    if (kind == M_ONEWAY && P->used_oneway < 1) return 0;
    if (kind == M_BRIDGE && P->used_bridge2 < 1) return 0;
    if (kind == M_GATE && P->used_gate < 1) return 0;
    if (kind == M_HUB && P->swaps < 1) return 0;
    if (kind == M_ICE && P->used_ice < 1) return 0;
    if (kind == M_WORKS && P->used_works < 1) return 0;
    if (kind == M_RET && !L->ret) return 0;
    static Level L2;
    static Solve S2;
    L2 = *L;
    strip_kind(&L2, kind);
    memset(&S2, 0, sizeof S2);
    solve(&L2, &S2, R->routes + 40, 60000);
    return S2.count != R->routes;
}

static int flavor_fits(const Slot *S, const Report *R) {
    const Sub *T = &R->T;
    const Drive *P = &R->D;
    int len = P->len > 0 ? P->len : 1;
    switch (S->flavor) {
    case F_DECOY: return T->opening;
    case F_LONGWAY: return T->away >= 1 && T->gap >= 5;
    case F_TWODOOR: return P->late_drops >= 1;
    case F_LONGCON: return T->nnr >= 1 && T->nr[0] * 10 <= len * 4;
    case F_GAUNTLET: return T->twists >= 4 && T->ntw >= 2 && T->tw[0] * 3 <= len && T->tw[T->ntw - 1] * 2 >= len;
    case F_KNOT: return P->cover >= 0.88 && P->turns * 10 >= len * 3;
    case F_DUMP: return P->dumps >= 1;
    case F_RESTOCK: return P->pickups >= 1 && P->buried >= 1;
    case F_SORTER: return P->swaps >= 1;
    case F_TWIN: return R->plans == 2;
    case F_HOARD: return P->max_load >= 7;
    case F_BREATHER: return R->routes >= 2;
    default: return 1;
    }
}

static double fit_of(const Level *L, Eval *E, const Slot *S) {
    const Report *R = &E->R;
    const Sub *T = &R->T;
    const Drive *P = &R->D;
    double f = 10, routes = (double)R->routes;
    if (routes > S->rmax) f -= 3.0 * log2(routes / S->rmax) + (R->capped ? 2 : 0);
    if (routes < S->rmin) f -= 2.0 * (S->rmin - routes);
    // The tries band. The floor is judged with each junction's cost capped (one giant dead end doesn't make
    // a level hard enough); the ceiling on the real figure (but it does make it too hard).
    double e = T->tsum < T->E ? T->tsum : T->E;
    if (e < S->elo) f -= 4.0 * log2((S->elo + 0.3) / (e + 0.3));
    if (T->E > S->ehi) f -= 3.0 * log2((T->E + 0.3) / (S->ehi + 0.3));
    if (T->F > S->fmax) f -= 5.0 * (T->F - S->fmax);
    // The plan view: what an experienced player has to hold in their head and work through.
    const PlanView *V = &R->V;
    if (V->ptries < S->pelo) f -= 4.0 * log2((S->pelo + 0.3) / (V->ptries + 0.3));
    if (V->ptries > S->pehi) f -= 3.0 * log2((V->ptries + 0.3) / (S->pehi + 0.3));
    if (V->pfirst > S->pfmax) f -= 5.0 * (V->pfirst - S->pfmax);
    if (S->pnmin && V->pnodes < S->pnmin) f -= 2.0 * log2((double)S->pnmin / (V->pnodes > 0 ? V->pnodes : 1));
    if (S->pnmax && V->pnodes > S->pnmax) f -= 2.0 * log2((double)V->pnodes / S->pnmax);
    if (S->pwmin && V->plans < S->pwmin) f -= 1.5 * log2((double)(S->pwmin + 1) / (V->plans + 1));
    if (V->over) f -= 3;
    if (P->picks < S->pickmin) f -= 0.6 * (S->pickmin - P->picks);       // "which building next?" has to be a real question
    if (S->open_end && P->last_doors < 2) f -= 1.5;          // a one-door house for the last package gives the ending away
    if (S->d1max >= 0 && R->doors1 > S->d1max) f -= 0.7 * (R->doors1 - S->d1max);
    if (R->doors1 < S->d1min) f -= 1.5 * (S->d1min - R->doors1);
    double tw = T->twists + 0.5 * T->forks;
    if (tw < S->twmin) f -= 1.0 * (S->twmin - tw);
    if (T->nears < S->nearmin) f -= 0.8 * (S->nearmin - T->nears);
    if (S->late && !(T->ntw > 0 && T->tw[T->ntw - 1] * 2 >= P->len)) f -= 1.0;
    if (S->qmax && P->quiet > S->qmax) f -= 0.4 * (P->quiet - S->qmax);        // deliveries all along the way, not saved for the end
    if (S->spread) {                    // twists in this many different thirds of the drive
        int third[3] = {0, 0, 0}, n3 = 0;
        for (int i = 0; i < T->ntw; i++) third[T->tw[i] * 3 / (P->len + 1) > 2 ? 2 : T->tw[i] * 3 / (P->len + 1)] = 1;
        n3 = third[0] + third[1] + third[2];
        if (n3 < S->spread) f -= 1.0 * (S->spread - n3);
    }
    if (R->nodes > S->nodes_max) f -= 2.0 * log2((double)R->nodes / S->nodes_max);
    if (P->len < S->len_min) f -= 0.3 * (S->len_min - P->len);
    if (S->len_max && P->len > S->len_max) f -= 0.2 * (P->len - S->len_max);
    if (S->turns_max && P->turns > S->turns_max) f -= 0.25 * (P->turns - S->turns_max);
    if (P->cover < S->cover_min) f -= 12.0 * (S->cover_min - P->cover);
    if (R->packages < S->pkmin) f -= 1.0 * (S->pkmin - R->packages);
    if (R->packages > S->pkmax) f -= 1.0 * (R->packages - S->pkmax);
    if (R->colours < S->colmin) f -= 1.5 * (S->colmin - R->colours);
    if (S->mono > 0) {                  // no one colour hogging the van
        int per[8] = {0}, top = 0;
        for (int k = 0; k < L->nh; k++) per[L->hcol[k]] += L->hord[k];
        for (int c = 0; c < 6; c++)
            if (per[c] > top) top = per[c];
        double share = (double)top / (L->total > 0 ? L->total : 1);
        if (share > S->mono) f -= 8.0 * (share - S->mono);
    }
    if (R->over) f -= 4;
    E->need_ok = 1;
    for (int k = 0; k < NKIND; k++)
        if (S->need[k] && !kind_matters(L, R, k)) {
            f -= 3;
            E->need_ok = 0;
        }
    E->flavor_ok = flavor_fits(S, R);
    if (!E->flavor_ok) f -= 2;
    f -= 0.08 * R->mech_tiles;          // signs only where they earn their place
    // Between two levels that both fit: more near misses, more twists, a plainer answer.
    f += 0.12 * (T->nears > 3 ? 3 : T->nears) + 0.08 * (T->twists > 6 ? 6 : T->twists) - 0.015 * P->turns;
    if (S->melter) f += 0.03 * (T->gap > 10 ? 10 : T->gap) + (T->opening ? 0.3 : 0);
    return f;
}

static int g_sol2[MAXSOL][MAXR], g_sollen2[MAXSOL];
static int g_gbest, g_gdepth;
static void gift_search(const Level *L, const State *s, int depth, u128 onroute);

// Is there road for a present a few tiles on from where this route ends?
static int gift_after(const Level *L, const int *route, int len, u128 on) {
    if (L->ret) return -1;
    State s;
    state_init(L, &s);
    for (int i = 0; i + 1 < len; i++) {
        int d;
        for (d = 0; d < 4; d++)
            if (L->nb[s.pos][d] == route[i + 1]) break;
        if (d == 4) return -1;
        on |= BIT(route[i + 1]);
        step(L, &s, d, route[i + 1], NULL);
    }
    g_gbest = -1;
    g_gdepth = 0;
    gift_search(L, &s, 0, on | BIT(route[0]));
    return g_gbest;
}

// Build, solve, walk the tree for the slot's player, and score the fit. 0 if the design isn't a level.
static int evaluate(const Design *D, const Slot *S, Level *L, Eval *E, long budget) {
    if (!build_level(D, L, &E->eff)) return 0;
    Report *R = &E->R;
    memset(R, 0, sizeof *R);
    static Solve SV;
    memset(&SV, 0, sizeof SV);
    SV.keep = 1;
    SV.maxkeep = MAXSOL;
    SV.routes = g_sol2;
    SV.rlen = g_sollen2;
    solve(L, &SV, 400, 80000);
    if (SV.count == 0) return 0;
    R->routes = SV.count;
    R->nodes = SV.nodes;
    R->capped = SV.capped;
    R->shortest = SV.short_len - 1;
    E->nshort = SV.nshort;
    census(L, R);
    R->who = S->who;
    if (SV.capped || SV.count > 40 * S->rmax + 40) {
        // Far too open to be worth walking: just say how far off it is.
        E->fit = -20.0 - 3.0 * log2((double)SV.count + (SV.capped ? 400 : 0));
        E->flavor_ok = E->need_ok = 0;
        return 1;
    }
    uint64_t seen[MAXSOL];
    int np = 0;
    for (int k = 0; k < SV.nkept; k++) {
        uint64_t hsh = plan_hash(L, g_sol2[k], g_sollen2[k]);
        int dup = 0;
        for (int j = 0; j < np; j++)
            if (seen[j] == hsh) dup = 1;
        if (!dup) seen[np++] = hsh;
    }
    R->plans = np;
    State s0;
    state_init(L, &s0);
    set_player(S->who);
    g_budget = budget;
    g_over = 0;
    R->T = walk(L, &s0);
    R->over = g_over;
    if (R->T.wins <= 0) return 0;
    R->route[0] = L->start;
    memcpy(R->route + 1, g_line[0], sizeof(int) * (size_t)R->T.len);
    R->route_len = R->T.len + 1;
    R->ok = drive(L, R->route, R->route_len, &R->D);
    if (!R->ok) return 0;
    plan_view(L, &R->V, 400000);
    R->tries[S->who] = R->T.E;
    R->first[S->who] = R->T.F;
    E->fit = fit_of(L, E, S);
    if (S->gift && gift_after(L, R->route, R->route_len, 0) < 0) E->fit -= 2;
    if (S->fuel) {
        // A fuel level: the tank holds the shortest route. Lots of ways to win, but one short enough, and the
        // way that comes to mind first is a little too long.
        if (E->nshort != 1) E->fit -= 2.0 * log2((double)E->nshort + 1.0);
        int extra = R->D.len - R->shortest;
        if (extra < 2) E->fit -= 2.0 * (2 - extra);
        if (extra > 8) E->fit -= 0.3 * (extra - 8);
    }
    return 1;
}

// ------------------------------------------------------------------ writing a level out

static void print_level(const Level *L) {
    printf("\"w\":%d,\"h\":%d,\"ret\":%d,\"map\":\"", L->w, L->h, L->ret);
    for (int c = 0; c < L->n; c++) {
        if (c) putchar(c % L->w ? ' ' : '/');
        int hk = -1, sk = -1;
        for (int k = 0; k < L->nh; k++)
            if (L->hcell[k] == c) hk = k;
        for (int k = 0; k < L->ns; k++)
            if (L->scell[k] == c) sk = k;
        if (hk >= 0) {
            putchar(L->hcol[hk] == ANY ? 'w' : COLS[L->hcol[hk]]);
            if (L->hord[hk] > 1) printf("%d", L->hord[hk]);
        } else if (sk >= 0) {
            putchar(COLS[L->scol[sk]] - 32);
            if (L->scnt[sk] > 1) printf("%d", L->scnt[sk]);
        } else if (!L->road[c])
            putchar('.');
        else if (c == L->start)
            putchar('S');
        else if (L->bridge[c])
            putchar('+');
        else if (L->hub[c])
            putchar('@');
        else if (L->ice[c])
            putchar('~');
        else if (L->oneway[c] >= 0)
            putchar("^>v<"[L->oneway[c]]);
        else if (L->gate[c] >= 0)
            printf("=%c", COLS[L->gate[c]]);
        else if (L->works[c])
            printf("c%d", L->works[c]);
        else
            putchar('#');
    }
    printf("\",\"stack\":\"");
    if (L->nstack == 0) putchar('-');
    for (int j = 0; j < L->nstack; j++) putchar(COLS[L->stack0[j]]);
    printf("\"");
}

// A place for a present: plain road no winning line needs, a few tiles on from where the drive ends ("the
// extra mile"). -1 if there's nowhere.
static void gift_search(const Level *L, const State *s, int depth, u128 onroute) {
    if (depth >= 5) return;
    for (int d = 0; d < 4; d++) {
        int nx = can_extend(L, s, d);
        if (nx < 0) continue;
        State t = *s;
        step(L, &t, d, nx, NULL);
        if (depth + 1 >= 2 && depth + 1 <= 4 && !(onroute & BIT(nx)) && L->road[nx] && L->oneway[nx] < 0 && L->gate[nx] < 0 && !L->bridge[nx] &&
            !L->hub[nx] && !L->ice[nx] && !L->works[nx] && depth + 1 > g_gdepth) {
            g_gdepth = depth + 1;
            g_gbest = nx;
        }
        gift_search(L, &t, depth + 1, onroute);
    }
}

// The game's hints follow the shortest winning route, so the present must be off that one too.
static int gift_spot(const Level *L, const Report *R) {
    static Solve SV;
    memset(&SV, 0, sizeof SV);
    solve(L, &SV, 400, 200000);
    if (SV.count == 0) return -1;
    u128 on = 0;
    for (int i = 0; i < R->route_len; i++) on |= BIT(R->route[i]);
    return gift_after(L, SV.shortest, SV.short_len, on);
}

static double now_secs(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void print_report_json(const Level *L, const Report *R);

static void print_cand(const Slot *S, const Level *L, const Eval *E, int restart) {
    static Report R;
    static Level L2;
    L2 = *L;
    snprintf(L2.id, sizeof L2.id, "%d", S->slot);
    report(&L2, &R, 3000000, S->who);
    if (!R.ok) return;
    printf("CAND {\"slot\":%d,\"seed\":%d,\"restart\":%d,\"fit\":%.3f,\"flavor\":\"%s\",\"flavor_ok\":%d,\"need_ok\":%d,", S->slot, S->seed, restart,
           E->fit, FLAVOR_NAME[S->flavor], E->flavor_ok, E->need_ok);
    print_level(&L2);
    int g = S->gift ? gift_spot(&L2, &R) : -1;
    if (g >= 0) printf(",\"gift\":[%d,%d]", g % L2.w, g / L2.w);
    printf(",\"matters\":{");
    int first = 1;
    for (int k = 0; k < NKIND; k++) {
        int present = 0;
        for (int c = 0; c < L2.n; c++) {
            if (k == M_ONEWAY && L2.oneway[c] >= 0) present = 1;
            if (k == M_BRIDGE && L2.bridge[c]) present = 1;
            if (k == M_GATE && L2.gate[c] >= 0) present = 1;
            if (k == M_HUB && L2.hub[c]) present = 1;
            if (k == M_ICE && L2.ice[c]) present = 1;
            if (k == M_WORKS && L2.works[c]) present = 1;
        }
        if (k == M_PICK && L2.ns) present = 1;
        if (k == M_RET && L2.ret) present = 1;
        for (int h = 0; h < L2.nh; h++) {
            if (k == M_LOCK && L2.hcol[h] == ANY) present = 1;
            if (k == M_MULTI && L2.hcol[h] != ANY && L2.hord[h] > 1) present = 1;
        }
        for (int h = 0; h < L2.ns; h++)
            if (k == M_WH && L2.scnt[h] >= 3) present = 1;
        if (!present) continue;
        printf("%s\"%s\":%d", first ? "" : ",", KIND_NAME[k], kind_matters(&L2, &R, k));
        first = 0;
    }
    printf("},\"m\":");
    print_report_json(&L2, &R);
    printf("}\n");
    fflush(stdout);
}

// ------------------------------------------------------------------ the search

#define TOPK 24
static Level g_topL[TOPK];
static Eval g_topE[TOPK];
static Design g_topD[TOPK];
static int g_ntop;

static int same_town(const Level *a, const Level *b) {
    return a->w == b->w && a->h == b->h && a->start == b->start && !memcmp(a->road, b->road, sizeof a->road);
}

// Keep the best few, one per town (two levels on the same roads would feel like the same level).
static void keep_best(const Design *D, const Level *L, const Eval *E, int keep) {
    if (keep > TOPK) keep = TOPK;
    for (int i = 0; i < g_ntop; i++)
        if (same_town(&g_topL[i], L)) {
            if (E->fit > g_topE[i].fit) {
                g_topL[i] = *L;
                g_topE[i] = *E;
                g_topD[i] = *D;
            }
            return;
        }
    int at = g_ntop;
    if (g_ntop < keep)
        g_ntop++;
    else {
        at = 0;
        for (int i = 1; i < g_ntop; i++)
            if (g_topE[i].fit < g_topE[at].fit) at = i;
        if (g_topE[at].fit >= E->fit) return;
    }
    g_topL[at] = *L;
    g_topE[at] = *E;
    g_topD[at] = *D;
}

// Take out every arrow, gate, hub, patch of ice and roadworks that changes nothing (the level fits its
// slot just as well without it). What's left is doing a job.
static void prune_idle(Design *D, const Slot *S, Level *L, Eval *E) {
    static Design t;
    static Level L2;
    static Eval e2;
    for (int c = 0; c < D->w * D->h; c++) {
        if (!D->road[c] || !(D->oneway[c] >= 0 || D->gate[c] >= 0 || D->hub[c] || D->ice[c] || D->works[c])) continue;
        t = *D;
        t.oneway[c] = t.gate[c] = -1;
        t.hub[c] = t.ice[c] = t.works[c] = 0;
        if (evaluate(&t, S, &L2, &e2, 300000) && e2.fit >= E->fit - 0.05) {
            *D = t;
            *L = L2;
            *E = e2;
        }
    }
}

int cmd_gen(int argc, char **argv) {
    static Slot S;
    slot_defaults(&S);
    for (int i = 2; i < argc; i++) slot_arg(&S, argv[i]);
    g_rng = 0x9E3779B97F4A7C15ULL ^ ((uint64_t)S.seed * 0xD1B54A32D192ED03ULL) ^ ((uint64_t)S.slot * 0x8CB92BA72F3D8DD7ULL);
    for (int i = 0; i < 20; i++) rnd64();
    double t0 = now_secs();
    long steps = S.steps > 0 ? S.steps : 20000;
    static Design cur, nxt, dbest;
    static Level L, Lbest;
    static Eval ecur, enxt, ebest;
    long evals = 0, restarts = 0;
    while (now_secs() - t0 < S.secs) {
        // A town, an answer, and a first set of buildings that works.
        int ok = 0;
        for (int tries = 0; tries < 200 && !ok; tries++) {
            if (!make_map(&cur, &S) || !make_route(&cur, &S)) continue;
            for (int b = 0; b < 30 && !ok; b++)
                if (first_buildings(&cur, &S) && evaluate(&cur, &S, &L, &ecur, 150000)) ok = 1;
        }
        if (!ok) continue;
        restarts++;
        ebest = ecur;
        Lbest = L;
        dbest = cur;
        double T0 = 1.0, T1 = 0.05;
        for (long step = 0; step < steps; step++) {
            if ((step & 255) == 0 && now_secs() - t0 > S.secs * 1.5) break;
            nxt = cur;
            int did = 0;
            for (int k = 0; k < 6 && !did; k++) did = mutate(&nxt, &S);
            if (!did) continue;
            if (rint_(100) < 20) mutate(&nxt, &S);          // sometimes two at once: a way over a ridge
            if (!evaluate(&nxt, &S, &L, &enxt, 150000)) continue;
            evals++;
            double T = T0 * pow(T1 / T0, (double)step / steps);
            if (enxt.fit >= ecur.fit || rflt() < exp((enxt.fit - ecur.fit) / T)) {
                cur = nxt;
                ecur = enxt;
                if (ecur.fit > ebest.fit + 1e-9) {
                    ebest = ecur;
                    Lbest = L;
                    dbest = cur;
                }
            }
        }
        if (S.verbose)
            fprintf(stderr, "# slot %d restart %ld: fit %.2f routes %ld tries %.2f first %.2f twists %d\n", S.slot, restarts, ebest.fit,
                    ebest.R.routes, ebest.R.T.E, ebest.R.T.F, ebest.R.T.twists);
        if (ebest.fit > 4) keep_best(&dbest, &Lbest, &ebest, S.keep);
    }
    for (int i = 0; i < g_ntop; i++) {
        prune_idle(&g_topD[i], &S, &g_topL[i], &g_topE[i]);
        print_cand(&S, &g_topL[i], &g_topE[i], i);
    }
    fprintf(stderr, "# slot %d: %d kept of %ld towns, %ld levels tried, %.1fs\n", S.slot, g_ntop, restarts, evals, now_secs() - t0);
    return 0;
}
