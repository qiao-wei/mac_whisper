import React, { useState, useRef, useEffect } from 'react';
import { 
  Undo, 
  Trash2, 
  Upload, 
  AlignJustify, 
  Languages, 
  Play, 
  ChevronDown,
  Settings,
  Type,
  ChevronRight,
  ChevronLeft,
  Combine,
  Scissors // Import Scissors for Split
} from 'lucide-react';

const SubtitleEditor = () => {
  // Mock data
  const [subtitles, setSubtitles] = useState([
    {
      id: 1,
      startTime: '00:00:15,250',
      endTime: '00:00:18,100',
      text: 'This is the first line of the subtitle.',
      translatedText: 'Esta es la primera línea del subtítulo.',
      selected: false
    },
    {
      id: 2,
      startTime: '00:00:18,500',
      endTime: '00:00:21,300',
      text: 'And this is the\nsecond line example.',
      translatedText: 'Y esta es la segunda línea,\ndemostrando el contenido.',
      selected: true
    },
    {
      id: 3,
      startTime: '00:00:22,000',
      endTime: '00:00:25,150',
      text: 'Each row represents a single subtitle segment.',
      translatedText: 'Cada fila representa un único segmento de subtítulo.',
      selected: false
    },
    {
      id: 4,
      startTime: '00:00:26,000',
      endTime: '00:00:28,900',
      text: 'Users can edit the text and timing directly in this list.',
      translatedText: 'Los usuarios pueden editar el texto y la sincronización directamente en esta lista.',
      selected: false
    },
    {
      id: 5,
      startTime: '00:00:30,100',
      endTime: '00:00:33,500',
      text: 'More subtitle content can be scrolled through.',
      translatedText: 'Se puede desplazar por más contenido de subtítulos.',
      selected: false
    }
  ]);

  const [isPlaying, setIsPlaying] = useState(false);
  const [showPreview, setShowPreview] = useState(true);
  
  // New state to track what content to show in preview: 'text' or 'translatedText'
  const [previewMode, setPreviewMode] = useState('text');
  
  // State for tracking which cell is being edited: { id: 1, field: 'text' }
  const [editingCell, setEditingCell] = useState({ id: null, field: null });
  
  // Ref for textarea auto-focus
  const editInputRef = useRef(null);

  // Helper to adjust textarea height
  const adjustHeight = (el) => {
    if (el) {
      el.style.height = 'auto';
      el.style.height = `${el.scrollHeight}px`;
    }
  };

  // Focus input when editing starts and adjust height
  useEffect(() => {
    if (editingCell.id && editInputRef.current) {
      const el = editInputRef.current;
      el.focus();
      
      // Auto-resize if it's a textarea
      if (el.tagName === 'TEXTAREA') {
          adjustHeight(el);
      }
      
      // Set cursor to end
      const val = el.value;
      el.setSelectionRange(val.length, val.length);
    }
  }, [editingCell]);

  // --- HELPER: Time conversion & Parsing ---
  const parseTimeToMs = (timeStr) => {
    if (!timeStr) return 0;
    const [h, m, sWithMs] = timeStr.split(':');
    const [s, ms] = sWithMs.split(',');
    return (parseInt(h) * 3600 + parseInt(m) * 60 + parseInt(s)) * 1000 + parseInt(ms);
  };

  const formatMsToTime = (totalMs) => {
    const h = Math.floor(totalMs / 3600000);
    const m = Math.floor((totalMs % 3600000) / 60000);
    const s = Math.floor((totalMs % 60000) / 1000);
    const ms = totalMs % 1000;
    
    const pad = (n, width = 2) => n.toString().padStart(width, '0');
    return `${pad(h)}:${pad(m)}:${pad(s)},${pad(ms, 3)}`;
  };

  const getProgressPercentage = (timeStr) => {
    if (!timeStr) return 0;
    const totalSeconds = parseTimeToMs(timeStr) / 1000;
    const mockTotalDuration = 120; // Assume video is 2 minutes long for demo
    return Math.min((totalSeconds / mockTotalDuration) * 100, 100);
  };

  // --- SELECTION LOGIC ---

  // Handle clicking the Row Body (Single Select)
  const handleRowClick = (id) => {
    setSubtitles(subtitles.map(sub => ({
      ...sub,
      selected: sub.id === id
    })));
  };

  // Handle clicking the Checkbox (Range/Continuous Select)
  const handleCheckboxClick = (e, clickedIndex) => {
    e.stopPropagation();

    // Find currently selected indices
    const selectedIndices = subtitles
      .map((sub, idx) => sub.selected ? idx : -1)
      .filter(idx => idx !== -1);
    
    let newSubtitles = [...subtitles];

    // Case 1: No previous selection, just select clicked
    if (selectedIndices.length === 0) {
      newSubtitles[clickedIndex].selected = true;
    } 
    // Case 2: There is a selection
    else {
      const minSel = Math.min(...selectedIndices);
      const maxSel = Math.max(...selectedIndices);

      // If clicking inside the existing range
      if (clickedIndex >= minSel && clickedIndex <= maxSel) {
        // Allow deselecting from edges to shrink range
        if (clickedIndex === minSel) {
          // Uncheck top
          newSubtitles[clickedIndex].selected = false;
        } else if (clickedIndex === maxSel) {
          // Uncheck bottom
          newSubtitles[clickedIndex].selected = false;
        } else {
          // Middle click - enforce continuity (do nothing or show toast)
        }
      } 
      // If clicking outside (Extend range)
      else {
        const start = Math.min(minSel, clickedIndex);
        const end = Math.max(maxSel, clickedIndex);
        
        // Select everything in between (Auto-fill gaps)
        for (let i = 0; i < newSubtitles.length; i++) {
          newSubtitles[i].selected = (i >= start && i <= end);
        }
      }
    }
    
    setSubtitles(newSubtitles);
  };

  // --- MERGE & SPLIT LOGIC ---
  
  const handleMerge = () => {
    const selectedIndices = subtitles
      .map((sub, idx) => sub.selected ? idx : -1)
      .filter(idx => idx !== -1);

    if (selectedIndices.length < 2) return;

    const firstIdx = Math.min(...selectedIndices);
    const lastIdx = Math.max(...selectedIndices);

    const mergedSubs = subtitles.filter((sub, idx) => idx >= firstIdx && idx <= lastIdx);

    // Create new merged item
    const newItem = {
      id: mergedSubs[0].id, // Keep ID of the first one
      startTime: mergedSubs[0].startTime,
      endTime: mergedSubs[mergedSubs.length - 1].endTime,
      text: mergedSubs.map(s => s.text).join(' '),
      translatedText: mergedSubs.map(s => s.translatedText).join(' '),
      selected: true // Keep new item selected
    };

    // Construct new array
    const newSubtitles = [
      ...subtitles.slice(0, firstIdx),
      newItem,
      ...subtitles.slice(lastIdx + 1)
    ];

    // Re-index remaining IDs to stay clean
    const reindexedSubtitles = newSubtitles.map((sub, idx) => ({
      ...sub,
      id: idx + 1
    }));

    setSubtitles(reindexedSubtitles);
  };

  const handleSplit = () => {
    // Find the single selected item
    const selectedIdx = subtitles.findIndex(s => s.selected);
    if (selectedIdx === -1) return; 

    const original = subtitles[selectedIdx];
    
    // Calculate mid-point time
    const startMs = parseTimeToMs(original.startTime);
    const endMs = parseTimeToMs(original.endTime);
    const duration = endMs - startMs;
    const midMs = startMs + Math.floor(duration / 2);
    
    const midTimeStr = formatMsToTime(midMs);
    
    // Update original (first half)
    const firstHalf = {
      ...original,
      endTime: midTimeStr,
      // Keep original text in first half for user to edit manually
      selected: true 
    };

    // Create new (second half)
    const secondHalf = {
      id: original.id + 1, // Temporary ID
      startTime: midTimeStr,
      endTime: original.endTime,
      text: '', // Start empty for easy entry
      translatedText: '',
      selected: false 
    };
    
    // Insert and re-index
    const newSubtitles = [
      ...subtitles.slice(0, selectedIdx),
      firstHalf,
      secondHalf,
      ...subtitles.slice(selectedIdx + 1)
    ].map((sub, idx) => ({ ...sub, id: idx + 1 }));

    setSubtitles(newSubtitles);
  };

  // Get count of selected items for UI states
  const selectedCount = subtitles.filter(s => s.selected).length;
  
  // Get active subtitle for Preview (The first selected one)
  const activeSubtitle = subtitles.find(s => s.selected);


  // --- EDITING LOGIC ---

  // Handle cell click to start editing
  const handleCellClick = (e, id, field) => {
    e.stopPropagation(); // Prevent row selection when clicking input
    
    const targetSub = subtitles.find(s => s.id === id);
    if (!targetSub.selected) {
       handleRowClick(id); 
    }
    
    // Switch preview mode based on which column is clicked
    if (field === 'translatedText') {
      setPreviewMode('translatedText');
    } else if (field === 'text') {
      setPreviewMode('text');
    }
    
    setEditingCell({ id, field });
  };

  // Handle input change
  const handleInputChange = (e, id, field) => {
    const newValue = e.target.value;
    setSubtitles(subtitles.map(sub => 
      sub.id === id ? { ...sub, [field]: newValue } : sub
    ));
    
    // Auto resize on type
    if (e.target.tagName === 'TEXTAREA') {
        adjustHeight(e.target);
    }
  };

  // Handle input blur (stop editing)
  const handleInputBlur = () => {
    setEditingCell({ id: null, field: null });
  };

  // Handle special keys in inputs
  const handleKeyDown = (e, isTextarea) => {
    // Ctrl/Cmd + Enter to save
    if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
      handleInputBlur();
      return;
    }
    
    // Esc to cancel (blur)
    if (e.key === 'Escape') {
      handleInputBlur();
      return;
    }

    // Regular Enter behavior
    if (e.key === 'Enter') {
      if (!isTextarea) {
        // For single line inputs (time), Enter saves
        handleInputBlur();
      }
      // For textarea, Enter adds new line (default behavior)
    }
  };

  // Delete handler
  const handleDelete = (id, e) => {
    e.stopPropagation();
    setSubtitles(subtitles.filter(sub => sub.id !== id));
  };

  // Shared styles for text content to ensure perfect alignment
  // using leading-6 (1.5rem / 24px) for consistent line height
  const textStyleBase = "text-sm font-sans leading-6 w-full px-2 py-1 rounded border";

  // Helper to render editable cell
  const renderEditableCell = (sub, field, isTime = false) => {
    const isEditing = editingCell.id === sub.id && editingCell.field === field;

    if (isEditing) {
      if (isTime) {
        return (
          <input
            ref={editInputRef}
            value={sub[field]}
            onChange={(e) => handleInputChange(e, sub.id, field)}
            onBlur={handleInputBlur}
            onKeyDown={(e) => handleKeyDown(e, false)}
            className={`${textStyleBase} bg-[#1e2433] text-white border-blue-500 outline-none shadow-lg font-mono`}
          />
        );
      } else {
        return (
          <textarea
            ref={editInputRef}
            value={sub[field]}
            onChange={(e) => handleInputChange(e, sub.id, field)}
            onBlur={handleInputBlur}
            onKeyDown={(e) => handleKeyDown(e, true)}
            className={`${textStyleBase} bg-[#1e2433] text-white border-blue-500 outline-none shadow-xl resize-none overflow-hidden block`}
            style={{ minHeight: '34px' }} // Matches the height of a single line div with padding
          />
        );
      }
    }

    // Display mode
    return (
      <div 
        onClick={(e) => handleCellClick(e, sub.id, field)}
        className={`${textStyleBase} border-transparent hover:border-gray-700 cursor-text whitespace-pre-wrap ${
          isTime ? 'font-mono text-gray-400' : field === 'translatedText' ? 'text-gray-400' : 'text-gray-300'
        }`}
        style={{ minHeight: '34px' }}
        title="Click to edit"
      >
        {sub[field]}
      </div>
    );
  };

  return (
    <div className="flex flex-col h-screen bg-[#0f1115] text-gray-300 font-sans overflow-hidden">
      {/* Top Navigation Bar */}
      <header className="h-16 border-b border-gray-800 flex items-center justify-between px-6 bg-[#0f1115] shrink-0 z-20">
        <div className="flex items-center space-x-3 text-white">
           <div className="bg-gray-800 p-1.5 rounded-md">
             <div className="w-4 h-4 border-2 border-white rounded-sm"></div>
           </div>
          <span className="font-semibold text-lg tracking-wide">Subtitle Editor</span>
        </div>
        
        <div className="flex items-center space-x-4">
          <button className="px-5 py-2 rounded-md bg-[#2563eb] hover:bg-blue-600 text-white font-medium transition-colors text-sm flex items-center gap-2">
            <span>Merge to Video</span>
          </button>
          <button className="px-5 py-2 rounded-md border border-gray-600 hover:bg-gray-800 text-gray-300 font-medium transition-colors text-sm">
            Export Subtitles
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 flex overflow-hidden relative">
        
        {/* Toggle Button */}
        <button
          onClick={() => setShowPreview(!showPreview)}
          className={`
            absolute top-1/2 z-50 
            w-8 h-8 rounded-full flex items-center justify-center 
            bg-[#1e2029] border border-gray-700 text-gray-400 
            hover:text-white hover:border-gray-500 hover:bg-gray-700 
            shadow-lg backdrop-blur-sm transition-all duration-300 ease-in-out cursor-pointer
          `}
          style={{
             left: showPreview ? '60%' : '100%',
             transform: 'translate(-50%, -50%)' 
          }}
          title={showPreview ? "Hide Preview" : "Show Preview"}
        >
           <div 
             className="transition-transform duration-300"
             style={{
               transform: showPreview ? 'none' : 'translateX(-30%)'
             }}
           >
             {showPreview ? <ChevronRight size={16} /> : <ChevronLeft size={16} />} 
           </div>
        </button>

        {/* Left Panel: Subtitle List */}
        <section 
          className={`
            flex flex-col bg-[#0f1115] transition-all duration-300 ease-in-out h-full
            ${showPreview ? 'w-[60%] border-r border-gray-700' : 'w-full border-none'}
          `}
        >
          
          {/* Toolbar */}
          <div className="h-14 flex items-center justify-between px-4 border-b border-gray-800 shrink-0">
            <div className="flex items-center space-x-2 text-gray-400">
              <button className="p-2 hover:bg-gray-800 rounded-md transition-colors" title="Undo">
                <Undo size={18} />
              </button>
              <button className="p-2 hover:bg-gray-800 rounded-md transition-colors" title="Delete">
                <Trash2 size={18} />
              </button>
              
              {/* MERGE BUTTON */}
              <button 
                className={`p-2 rounded-md transition-colors flex items-center gap-1
                   ${selectedCount >= 2 
                     ? 'text-blue-400 hover:bg-[#1e2433] cursor-pointer' 
                     : 'text-gray-600 cursor-not-allowed opacity-50'}
                `}
                title={selectedCount >= 2 ? "Merge Selected Rows" : "Select consecutive rows to merge"}
                onClick={handleMerge}
                disabled={selectedCount < 2}
              >
                <Combine size={18} />
                {selectedCount >= 2 && <span className="text-xs font-semibold ml-1">Merge</span>}
              </button>

              {/* SPLIT BUTTON */}
              <button 
                className={`p-2 rounded-md transition-colors flex items-center gap-1
                   ${selectedCount === 1 
                     ? 'text-blue-400 hover:bg-[#1e2433] cursor-pointer' 
                     : 'text-gray-600 cursor-not-allowed opacity-50'}
                `}
                title={selectedCount === 1 ? "Split Selected Row" : "Select exactly one row to split"}
                onClick={handleSplit}
                disabled={selectedCount !== 1}
              >
                <Scissors size={18} />
                {selectedCount === 1 && <span className="text-xs font-semibold ml-1">Split</span>}
              </button>

              <div className="h-4 w-px bg-gray-700 mx-2"></div>
              <button className="p-2 hover:bg-gray-800 rounded-md transition-colors" title="Upload">
                <Upload size={18} />
              </button>
              <button className="p-2 hover:bg-gray-800 rounded-md transition-colors" title="Settings">
                <AlignJustify size={18} />
              </button>
            </div>

            <div className="flex items-center space-x-3">
              <button className="flex items-center space-x-2 bg-[#1e2433] text-blue-400 px-3 py-1.5 rounded-md hover:bg-[#252b3d] transition-colors border border-blue-900/30">
                <Languages size={16} />
                <span className="text-sm font-medium">Translate All</span>
              </button>
              <div className="flex items-center space-x-1 text-gray-400 text-sm cursor-pointer hover:text-white">
                <span>English</span>
                <ChevronDown size={14} />
              </div>
            </div>
          </div>

          {/* Table Header - Flexbox Layout */}
          <div className="flex items-center gap-4 px-6 py-3 text-xs font-semibold text-gray-500 uppercase border-b border-gray-800 shrink-0">
            <div className="w-10 flex items-center">
              <div className="w-4 h-4 border border-gray-600 rounded cursor-pointer"></div>
            </div>
            <div className="w-24 pl-2">Start Time</div>
            <div className="w-24 pl-2">End Time</div>
            <div className="flex-1 pl-2">Subtitle Text</div>
            <div className="flex-1 pl-2">Translated Text</div>
            <div className="w-24 text-right pr-2">Actions</div>
          </div>

          {/* Table Body - Flexbox Layout */}
          <div className="flex-1 overflow-y-auto custom-scrollbar">
            {subtitles.map((sub, index) => (
              <div 
                key={sub.id}
                onClick={() => handleRowClick(sub.id)}
                className={`
                  flex items-start gap-4 px-6 py-3 border-b border-gray-800/50 cursor-default transition-colors group relative
                  ${sub.selected ? 'bg-[#111c30] border-l-2 border-l-blue-500' : 'hover:bg-[#15181e] border-l-2 border-l-transparent'}
                `}
                style={{
                  // Fix padding offset caused by border-l-2
                  paddingLeft: sub.selected || (!sub.selected) ? '1.5rem' : '1.5rem' 
                }}
              >
                {/* Checkbox & ID - Fixed Width */}
                <div className="w-10 shrink-0 flex items-start pt-2 space-x-4">
                  <div 
                    className={`w-4 h-4 border rounded flex items-center justify-center transition-colors cursor-pointer mt-0.5 shrink-0
                      ${sub.selected ? 'bg-blue-600 border-blue-600' : 'border-gray-600'}
                    `}
                    onClick={(e) => handleCheckboxClick(e, index)}
                  >
                    {sub.selected && <div className="w-2 h-1.5 border-l-2 border-b-2 border-white rotate-[-45deg] mb-0.5"></div>}
                  </div>
                  <span className={`text-sm mt-0.5 ${sub.selected ? 'text-blue-400' : 'text-gray-400'}`}>{sub.id}</span>
                </div>

                {/* Editable Fields */}
                <div className="w-24 shrink-0 text-sm pt-1">
                  {renderEditableCell(sub, 'startTime', true)}
                </div>
                <div className="w-24 shrink-0 text-sm pt-1">
                   {renderEditableCell(sub, 'endTime', true)}
                </div>

                <div className="flex-1 min-w-0">
                  {renderEditableCell(sub, 'text')}
                </div>

                <div className="flex-1 min-w-0">
                   {renderEditableCell(sub, 'translatedText')}
                </div>

                {/* Actions - Fixed Width */}
                <div className="w-24 shrink-0 flex items-start justify-end space-x-2 pt-2 opacity-0 group-hover:opacity-100 transition-opacity">
                   <button 
                     onClick={(e) => handleDelete(sub.id, e)}
                     className="text-gray-500 hover:text-red-400 transition-colors p-1"
                   >
                     <Trash2 size={16} />
                   </button>
                   <button className="text-gray-500 hover:text-blue-400 transition-colors p-1">
                     <Type size={16} />
                   </button>
                   <button className="text-gray-500 hover:text-white transition-colors p-1">
                     <Settings size={16} />
                   </button>
                </div>
              </div>
            ))}
            
            {/* Empty State / Scroll Spacer */}
            <div className="h-32"></div>
          </div>
        </section>

        {/* Right Panel: Video Preview */}
        <section 
          className={`
             bg-[#0f1115] p-6 flex flex-col items-center border-l border-gray-900 shadow-2xl z-10 h-full
             transition-all duration-300 ease-in-out overflow-hidden whitespace-nowrap
             ${showPreview ? 'w-[40%] opacity-100' : 'w-0 opacity-0 p-0 border-none'}
          `}
        >
            <div className="w-full h-full flex flex-col min-w-[300px]"> 
                <div className="w-full bg-[#1e2029] rounded-lg overflow-hidden shadow-2xl relative group aspect-video flex flex-col border border-gray-800 shrink-0">
                
                {/* Mock Video Screen */}
                <div className="flex-1 bg-gradient-to-br from-gray-800 to-gray-900 flex items-center justify-center relative">
                    <div className="absolute inset-0 opacity-10 pointer-events-none" style={{ backgroundImage: 'url("data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0IiBoZWlnaHQ9IjQiPgo8cmVjdCB3aWR0aD0iNCIgaGVpZ2h0PSI0IiBmaWxsPSIjZmZmIi8+CjxyZWN0IHdpZHRoPSIxIiBoZWlnaHQ9IjEiIGZpbGw9IiMwMDAiLz4KPC9zdmc+")' }}></div>
                    
                    {/* SUBTITLE PREVIEW OVERLAY */}
                    {activeSubtitle && (
                      <div className="absolute bottom-12 left-8 right-8 text-center pointer-events-none z-20">
                         <div className="inline-block bg-black/60 backdrop-blur-sm px-4 py-2 rounded-lg">
                           <p className="text-white text-lg font-medium drop-shadow-md whitespace-pre-wrap leading-tight">
                             {activeSubtitle[previewMode]}
                           </p>
                         </div>
                      </div>
                    )}

                    <button 
                    onClick={() => setIsPlaying(!isPlaying)}
                    className="w-16 h-16 bg-black/40 hover:bg-black/60 backdrop-blur-sm rounded-full flex items-center justify-center transition-all transform hover:scale-105"
                    >
                    <Play size={32} className="text-white ml-1 fill-white" />
                    </button>

                    <div className="absolute top-4 right-4 text-xs font-mono text-white/50 bg-black/40 px-2 py-1 rounded">
                        FPS: 24.0
                    </div>
                </div>

                {/* Video Controls */}
                <div className="bg-black/40 backdrop-blur-md absolute bottom-0 left-0 right-0 p-3">
                    <div className="flex items-center justify-between mb-2">
                    <div className="h-1 bg-gray-600 rounded-full flex-1 mr-4 relative cursor-pointer group/progress">
                        {/* Dynamic Progress Bar */}
                        <div 
                          className="absolute top-0 left-0 h-full bg-white rounded-full transition-all duration-500 ease-out"
                          style={{ width: `${activeSubtitle ? getProgressPercentage(activeSubtitle.startTime) : 0}%` }}
                        ></div>
                        <div 
                          className="absolute top-1/2 -translate-y-1/2 w-3 h-3 bg-white rounded-full shadow-md scale-0 group-hover/progress:scale-100 transition-transform duration-500 ease-out"
                          style={{ left: `${activeSubtitle ? getProgressPercentage(activeSubtitle.startTime) : 0}%` }}
                        ></div>
                    </div>
                    </div>
                    <div className="flex justify-between items-center text-xs font-mono text-gray-300">
                    {/* Dynamic Timestamp */}
                    <span>
                      {activeSubtitle 
                        ? activeSubtitle.startTime.split(',')[0].replace(/^00:/, '') // Simple format to MM:SS
                        : '00:00'}
                    </span>
                    <span>02:00</span>
                    </div>
                </div>
                </div>

                <div className="mt-6 w-full text-center space-y-2">
                <p className="text-gray-500 text-sm font-medium">Preview Mode</p>
                <p className="text-gray-600 text-xs">Modifications in the list update in real-time</p>
                </div>
            </div>
        </section>

      </main>
      
      {/* Global CSS for scrollbar if needed */}
      <style>{`
        .custom-scrollbar::-webkit-scrollbar {
          width: 8px;
        }
        .custom-scrollbar::-webkit-scrollbar-track {
          background: #0f1115;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb {
          background: #2d3748;
          border-radius: 4px;
        }
        .custom-scrollbar::-webkit-scrollbar-thumb:hover {
          background: #4a5568;
        }
      `}</style>
    </div>
  );
};

export default SubtitleEditor;
