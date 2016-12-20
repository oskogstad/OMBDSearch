import dlangui;
import std.stdio;
import std.net.curl;
import std.json;
import std.array;
import std.algorithm;
import std.uri;
import std.format;

// dlangui entry
mixin APP_ENTRY_POINT;

const string IMDB_ID = "imdbID";
const string SEARCH = "Search";
const string TOEDDEL = "\"";
const string EMPTY = "";
const dstring EMPTY_D = ""d;

const uint SCREEN_WIDTH = 1200;
const uint SCREEN_HEIGHT = 600;

const int FONT_SIZE_SMALL = 23;
const int FONT_SIZE_MEDIUM = 50;
const int FONT_SIZE_LARGE = 70;
const int MARGIN_SMALL = 25;
const int MARGIN_MEDIUM = 120;
const int MARGIN_LARGE = 200;

const dstring TOO_MANY_RESULTS = "Too many results!"d;
const dstring MOVIE_NOT_FOUND = "No result!"d;
const dstring SEARCH_ERROR = "OMDB returned error!"d;
const dstring TITLE = "OMDBSearch"d;
const string SEARCH_URL = "http://www.omdbapi.com/?s=";
const string SINGLE_MOVIE_URL = "http://www.omdbapi.com/?i=%s&plot=short&r=json";
const dstring SEARCH_TOOLTIP = "Enter movie title ... "d;

const uint WIDGET_WRAPPER_COLOR = 0xDDDDDD;
const uint SCROLL_COLOR = 0xEFEFEF;
const uint MOVIE_COLOR = 0xEEEEEE;

const string ERROR_TOO_MANY_RESULTS = "{\"Response\":\"False\",\"Error\":\"Too many results.\"}";
const string ERROR_MOVIE_NOT_FOUND = "{\"Response\":\"False\",\"Error\":\"Movie not found!\"}";
const string ERROR_SEARCH_ERROR = "{\"Response\":\"False\",\"Error\":\"Something went wrong.\"}";

const string[] MOVIE_WIDGETS = 
[
    "Title",
    "Year",
    "Rated",
    "Released",
    "Runtime",
    "Genre",
    "Director",
    "Writer",
    "Actors",
    "Plot",
    "Awards",
    "imdbRating",
    "imdbVotes"
];

HorizontalLayout getTextWidgets(dstring labelText, JSONValue json)
{
    auto label = new TextWidget();
    label.fontSize = FONT_SIZE_SMALL;
    label.text = labelText;
    label.alignment = Align.Left;

    auto value = new TextWidget();
    auto jsonReplaced = replace(json.toString(), TOEDDEL, EMPTY);
    value.text = to!dstring(jsonReplaced);
    value.fontSize = FONT_SIZE_SMALL;
    value.alignment = Align.Right;
    
    label.layoutWidth = FILL_PARENT;
    // plot needs to wrap, too long string .. this is not working tho
    value.layoutHeight = WRAP_CONTENT;
    value.layoutWidth = FILL_PARENT;
                            
    auto wrapper = new HorizontalLayout();
    wrapper.layoutWidth = FILL_PARENT;
    wrapper.backgroundColor = WIDGET_WRAPPER_COLOR;
    wrapper.margins(Rect(MARGIN_LARGE, 0, MARGIN_MEDIUM, 0));

    wrapper.addChild(label);
    wrapper.addChild(value);

    return wrapper;
}

// main for dlangui
extern (C) int UIAppMain(string[] args) 
{
    auto window = Platform.instance.createWindow(TITLE, null, WindowFlag.Modal, SCREEN_WIDTH, SCREEN_HEIGHT);

    auto mainLayout = new VerticalLayout();
    
    auto statusLine = new StatusLine();
    statusLine.alignment = Align.Bottom;
    
    auto title = new TextWidget();
    title.text(TITLE);
    title.fontSize = FONT_SIZE_LARGE;
    title.alignment = Align.Center;

    auto searchResult = new VerticalLayout();
    auto scroll = new ScrollWidget();
    scroll.contentWidget = searchResult;
    scroll.hscrollbarMode = ScrollBarMode.Invisible;
    //scroll.vscrollbarMode = ScrollBarMode.Invisible;
    scroll.backgroundColor = SCROLL_COLOR;
    scroll.margins(Rect(MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL));
    
    auto searchBar = new EditLine();
    searchBar.fontSize = FONT_SIZE_MEDIUM;
    searchBar.margins(Rect(SCREEN_WIDTH/5, 0, SCREEN_WIDTH/5, 0));
    searchBar.tooltipText = SEARCH_TOOLTIP;
    searchBar.keyEvent = (Widget w, KeyEvent e) 
    {
        switch(e.keyCode) 
        {
            case KeyCode.RETURN:
            {
                searchResult.removeAllChildren();
                
                auto s = to!string(searchBar.text);
                auto url = SEARCH_URL ~ encode(s);
                
                foreach(line; byLine(url))
                {
                    switch(line)
                    {
                        case ERROR_TOO_MANY_RESULTS:
                            title.text = TOO_MANY_RESULTS;
                            break; 

                        case ERROR_MOVIE_NOT_FOUND:
                            title.text = MOVIE_NOT_FOUND;
                            break; 

                        case ERROR_SEARCH_ERROR:
                            title.text = SEARCH_ERROR;
                            break;

                        default:
                            title.text = TITLE;
                    }

                    auto result = parseJSON(line);

                    foreach(searchItem; result[SEARCH].array)
                    {
                        // wrapper per movie
                        auto movieLayout = new HorizontalLayout();
                        movieLayout.layoutWidth = FILL_PARENT;
                        movieLayout.alignment = Align.Right;
                        movieLayout.backgroundColor = MOVIE_COLOR;
                        movieLayout.margins(Rect(MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL));

                        auto imdbID = searchItem[IMDB_ID].toString();
                        imdbID = replace(imdbID, TOEDDEL, EMPTY);
                        auto singleMovieURL = format(SINGLE_MOVIE_URL, imdbID);
                        
                        JSONValue movieJSON;
                        foreach(movie; byLine(singleMovieURL))
                        {
                            movieJSON = parseJSON(movie);
                        }

                        // image on the left wut :(
                        // curl.download?
                        auto image = new ImageWidget();
                        image.margins(Rect(MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL));
                        image.alignment = Align.Left;

                        // textwrapper on the right
                        auto textWrapper = new VerticalLayout();
                        textWrapper.margins(Rect(MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL, MARGIN_SMALL));
                        textWrapper.alignment = Align.Right;
                        textWrapper.layoutWidth = FILL_PARENT;

                        foreach(str; MOVIE_WIDGETS)
                        {
                            auto widget = getTextWidgets(to!dstring(str), movieJSON[str]);
                            textWrapper.addChild(widget);
                        }

                        movieLayout.addChild(image);
                        movieLayout.addChild(textWrapper);
                        
                        searchResult.addChild(movieLayout);  
                    }

                    // this needs to be set after scroll has gained width, I think
                    searchResult.layoutWidth = scroll.width - 2 * MARGIN_SMALL;
                } 
                break;
            }

            // clear searchBar
            case KeyCode.ESCAPE:
            {
                searchBar.text = EMPTY_D;
                break;
            }
            default:
                // no case, let the default handle happens!
                return false;
        }     
        return true;
    };

    searchResult.alignment = Align.Center;

    mainLayout.addChild(title);
    mainLayout.addChild(searchBar);
    mainLayout.addChild(scroll);
    mainLayout.addChild(statusLine);
    mainLayout.layoutHeight = SCREEN_HEIGHT-300;

    window.mainWidget = mainLayout;

    window.show();

    return Platform.instance.enterMessageLoop();
}