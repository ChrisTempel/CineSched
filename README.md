This is still a work in progress.  It was vibe-coded with Claude, ChatGPT and Gemini.  
It is written in Swift and designed to run on MacOS Sequoia and higher.

Some features I'd like to evtually add include:
* .fdx import where scenes are added automatically to the Boneyard.  Scene naming convention is #: INT/EXT LOCATION .  For example, 13: EXT WOODS . Time of Day checkbox should mark automatically when the script is imported and Words like DAY or NIGHT should not be added to the Location description.
* Ability to select a single scene and have a border appear around it showing that it is selected.  Clicking off should clear the selection.
* Ability to laso select multiple scenes and move them at once
* Ability to double click a blank spot in the calendar to create and add a scene, bypassing the Boneyard
* Fix a bug where dropping a scene at the end of a day does not show the drop indicator.  We should always see a drop indicator
* Reduce the amount of space at the bottom of a cell during PDF export.

