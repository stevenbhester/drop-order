/**
 * Builds the Last Mile playtest survey as a Google Form in your own Google account, with a
 * spreadsheet for the answers.
 *
 *   1. Go to https://script.google.com and click "New project".
 *   2. Delete what's there, paste in this whole file, and click Save.
 *   3. Pick createLastMilePlaytestForm in the function menu and click Run. Google asks you to allow it
 *      to make forms and spreadsheets in your account: allow it.
 *   4. Open the Execution log (it opens by itself): it shows the link to send playtesters, and the
 *      link to edit the form. Both are also in your Google Drive.
 *
 * Three pages, most important first. Google Forms only keeps answers that get submitted, so each page
 * ends with "keep going, or send my answers now?": someone short on time sends page 1 and it still counts.
 *   Page 1 (a minute or so): how far, still playing, difficulty, recommend 0-10, how often they play six
 *     kinds of puzzle game (a grid: who's playing), and the one thing they'd change. Enough to judge a
 *     build, and who it's landing with.
 *   Page 2 (a minute of taps): why they stopped, Draw vs D-pad, which modes they enjoyed, the gas
 *     system, and real ads vs purchases once the placeholders go.
 *   Page 3 (optional): confusing levels or symbols, and their name.
 */
function createLastMilePlaytestForm() {
  const form = FormApp.create('Last Mile playtest (3 minutes)');
  form.setDescription(
    'Thanks for playtesting Last Mile! The first page takes about a minute and covers what matters most. ' +
    'After that you can send your answers, or keep going for two more short pages. Honest beats nice.\n\n' +
    'Found a bug? In the game, Options > Feedback / Bug report is quickest: it sends a screenshot and ' +
    'the game\'s log too.');
  form.setConfirmationMessage(
    'Thank you! This really does decide what happens next. If you think of anything later, ' +
    'Options > Feedback / Bug report in the game reaches Steven directly.');
  form.setCollectEmail(false);
  form.setAllowResponseEdits(false);
  form.setLimitOneResponsePerUser(false); // no Google sign-in needed to answer
  form.setProgressBar(true);
  form.setShowLinkToRespondAgain(false);

  // ---- Page 1: what matters most ----------------------------------------------------------------
  form.addMultipleChoiceItem()
    .setTitle('How far did you get?')
    .setChoiceValues(['Levels 1 to 10', '11 to 20', '21 to 40', '41 to 60', '61 to 90', '91 to 100',
      'I finished all 100'])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('Are you still playing?')
    .setChoiceValues(['Yes, most days', 'Now and then', 'No, I stopped'])
    .setRequired(true);

  form.addScaleItem()
    .setTitle('How did the difficulty feel overall?')
    .setHelpText('3 is just right.')
    .setBounds(1, 5)
    .setLabels('Way too easy', 'Way too hard')
    .setRequired(true);

  form.addScaleItem()
    .setTitle('How likely are you to recommend Last Mile to a friend?')
    .setBounds(0, 10)
    .setLabels('Not at all', 'Already have')
    .setRequired(true);

  // Who's playing: each row is a kind of puzzle player, from casual to keen. Sort & unjam and Path &
  // logic are Last Mile's nearest neighbours.
  form.addGridItem()
    .setTitle('How often do you play these kinds of phone games?')
    .setHelpText('One tap per row.')
    .setRows([
      'Match & pop (Candy Crush, Royal Match, Toon Blast)',
      'Sort & unjam (Water Sort, Parking Jam, Screw Sort)',
      'Daily brain teasers (Wordle, Connections, sudoku, crosswords)',
      'Path & logic puzzles (Flow Free, nonograms, Rush Hour)',
      'Clever indie puzzlers (Monument Valley, Mini Metro, Baba Is You)',
      'Classic cards & tiles (Solitaire, Mahjong, 2048)',
    ])
    .setColumns(['Never', 'Used to', 'Sometimes', 'Most days'])
    .setRequired(true);

  form.addParagraphTextItem()
    .setTitle('If you could change one thing, what would it be?');

  const more1 = form.addMultipleChoiceItem()
    .setTitle('Got another minute? The next page is all taps.')
    .setHelpText('Either way, your answers so far are saved once you send them.');

  // ---- Page 2: the decisions ---------------------------------------------------------------------
  const page2 = form.addPageBreakItem()
    .setTitle('A few more taps')
    .setHelpText('About a minute.');

  form.addCheckboxItem()
    .setTitle('If you stopped or slowed down, what did it?')
    .setHelpText('Pick any.')
    .setChoiceValues(['Got stuck on a level', 'It got too hard', 'It got repetitive', 'Ran out of gas',
      'The controls got frustrating', 'Life got busy', 'I finished it'])
    .showOtherOption(true);

  form.addGridItem()
    .setTitle('Steering: how did each feel?')
    .setRows(['Draw (drag your finger along the route)', 'D-pad (arrow buttons)'])
    .setColumns(['Didn\'t try it', 'Fiddly', 'Fine', 'Great'])
    .setRequired(true);

  form.addCheckboxItem()
    .setTitle('Which parts did you enjoy?')
    .setHelpText('Pick any.')
    .setChoiceValues(['The main levels', 'Daily puzzles', 'Speedrun', 'Side roads and treasure chests',
      'The Garage (paint jobs, hats)', 'The map and its little mysteries',
      'Ice, lockers and roadworks (the later mechanics)', 'Honestly, none of it grabbed me']);

  form.addMultipleChoiceItem()
    .setTitle('The gas tank you spend to start new levels...')
    .setChoiceValues(['Didn\'t really notice it', 'Felt fine', 'Was a bit annoying', 'Made me stop playing'])
    .setRequired(true);

  form.addMultipleChoiceItem()
    .setTitle('The ads and Dollaroos are placeholders for now. If Last Mile came out for real, which would you pick?')
    .setChoiceValues(['Free, with optional ads for extras (like undos)',
      'Free, plus a one-time purchase to remove ads', 'Pay once up front (about $3), no ads',
      'Free, with small in-app purchases (gas, cosmetics)', 'I wouldn\'t pay or watch ads for it'])
    .setRequired(true);

  const more2 = form.addMultipleChoiceItem()
    .setTitle('One last page: two optional boxes. Keep going?');

  // ---- Page 3: optional extras -------------------------------------------------------------------
  const page3 = form.addPageBreakItem()
    .setTitle('Last bit')
    .setHelpText('Both optional.');

  form.addParagraphTextItem()
    .setTitle('Was any level or symbol confusing or unfair?')
    .setHelpText('The level number helps, if you remember it.');

  form.addTextItem()
    .setTitle('Your name')
    .setHelpText('Only so Steven can say thanks or ask a follow-up. Leave it blank to stay anonymous.');

  // The checkpoints: keep going to the next page, or send now (the Next button becomes Submit).
  more1.setChoices([
    more1.createChoice('Yes, keep going', page2),
    more1.createChoice('No, send my answers now', FormApp.PageNavigationType.SUBMIT),
  ]).setRequired(true);
  more2.setChoices([
    more2.createChoice('Yes', page3),
    more2.createChoice('No, send my answers now', FormApp.PageNavigationType.SUBMIT),
  ]).setRequired(true);

  // Answers land in a spreadsheet as well as the form's own summary.
  const sheet = SpreadsheetApp.create('Last Mile playtest answers');
  form.setDestination(FormApp.DestinationType.SPREADSHEET, sheet.getId());

  // Open to anyone with the link. (A Google Workspace account would otherwise ask testers to sign in to
  // your domain; a personal account doesn't have these settings, so failures here are fine.)
  try { form.setRequireLogin(false); } catch (e) {}
  try { if (typeof form.setPublished === 'function') form.setPublished(true); } catch (e) {}
  form.setAcceptingResponses(true);

  let link = form.getPublishedUrl();
  try { link = form.shortenFormUrl(link); } catch (e) {}
  Logger.log('Send playtesters this link: ' + link);
  Logger.log('Edit the form here: ' + form.getEditUrl());
  Logger.log('Answers spreadsheet: ' + sheet.getUrl());
}
