//
//  PlaySpace.swift
//  islobsterble
//
//  Created by Finn Lidbetter on 2020-12-27.
//  Copyright © 2020 Finn Lidbetter. All rights reserved.
//

import SwiftUI

let SCREEN_SIZE: CGRect = UIScreen.main.bounds

let BLANK = Character("-")
let INVISIBLE = Character(" ")
let INVISIBLE_LETTER = Letter(letter: INVISIBLE, is_blank: false)
let NUM_RACK_TILES = 7
let NUM_BOARD_ROWS = 15
let NUM_BOARD_COLUMNS = 15

func initialLetters() -> [Letter] {
    var rackLetters: [Letter] = []
    rackLetters.append(Letter(letter: Character("A"), is_blank: false))
    rackLetters.append(Letter(letter: Character("B"), is_blank: false))
    rackLetters.append(Letter(letter: Character("C"), is_blank: false))
    rackLetters.append(Letter(letter: Character("D"), is_blank: false))
    rackLetters.append(Letter(letter: Character("E"), is_blank: false))
    rackLetters.append(Letter(letter: Character("-"), is_blank: true))
    rackLetters.append(Letter(letter: Character("-"), is_blank: true))
    return rackLetters
}
func initialScores() -> [String: Int] {
    return ["Player 1": 100, "Player 2": 101]
}

enum FrontTaker {
    /*
     * States for tracking whether board tiles or rack tiles should appear at the front.
     *
     * This allows tiles dragged from the board to appear over all rack tiles
     * and vice versa.
     */
    case unknown
    case board
    case rack
}

struct PlaySpace: View {
    let width: Int = Int(SCREEN_SIZE.width)
    let gameId: String
    @State private var scores: [String: Int] = initialScores()
    @State private var boardLetters = [[Letter]](repeating: [Letter](repeating: INVISIBLE_LETTER, count: NUM_BOARD_COLUMNS), count: NUM_BOARD_ROWS)
    @State private var locked = [[Bool]](repeating: [Bool](repeating: false, count: NUM_BOARD_COLUMNS), count: NUM_BOARD_ROWS)
    @State private var rackTilesOnBoardCount: Int = 0
    @State private var rackLetters: [Letter] = initialLetters()
    @State private var rackShuffleState: [Letter] = [Letter](repeating: INVISIBLE_LETTER, count: NUM_RACK_TILES)
    @State private var frontTaker: FrontTaker = FrontTaker.unknown
    
    // Variables for the blank picker.
    @State private var showBlankPicker = false
    @State private var prevBlankRow: Int? = nil
    @State private var prevBlankColumn: Int? = nil
    
    // Variables for the exchange picker.
    @State private var showExchangePicker = false
    @State private var exchangeChosen = [Bool](repeating: false, count: NUM_RACK_TILES)
    
    // Environment variables.
    @EnvironmentObject var boardSlots: SlotGrid
    @EnvironmentObject var rackSlots: SlotRow
    
    var body: some View {
        VStack {
            ScorePanel(scores: self.scores)
            Spacer()
            ZStack {
                VStack(spacing: 20) {
                    BoardBackground(boardSquares: setupBoardSquares())
                    RackBackground(rackSquares: setupRackSquares())
                }
                VStack(spacing: 20) {
                    BoardForeground(tiles: setupBoardTiles(), locked: self.locked, showingPicker: self.showBlankPicker || self.showExchangePicker).zIndex(self.frontTaker == FrontTaker.board ? 1 : 0)
                    RackForeground(tiles: setupRackTiles(), shuffleState: setupShuffleState(), showingPicker: self.showBlankPicker || self.showExchangePicker).zIndex(self.frontTaker == FrontTaker.rack ? 1 : 0)
                }
                BlankPicker(isPresented: $showBlankPicker, onSelection: self.setBlank)
                ExchangePicker(isPresented: $showExchangePicker, rackLetters: self.rackLetters, chosen: $exchangeChosen, onSelectTile: self.chooseTileForExchange, onExchange: self.confirmExchange)
            }
            ActionPanel(
                rackTilesOnBoard: self.rackTilesOnBoardCount > 0,
                showingPicker: self.showBlankPicker || self.showExchangePicker,
                onShuffle: self.shuffleTiles,
                onRecall: self.recallTiles,
                onPass: self.confirmPass,
                onPlay: self.confirmPlay,
                onExchange: self.selectExchange
            )
        }.navigationBarTitle("Game", displayMode: .inline)
    }
    func chooseTileForExchange(index: Int) {
        self.exchangeChosen[index] = !self.exchangeChosen[index]
    }
    func confirmExchange() {
        
    }
    func confirmPass() {
        
    }
    func confirmPlay() {
        
    }
    func selectExchange() {
        self.recallTiles()
        self.showExchangePicker = true
    }
    
    func shuffleTiles() {
        let order = UtilityFuncs.permutation(size: NUM_RACK_TILES)
        var copy: [Letter] = []
        for index in 0..<NUM_RACK_TILES {
            copy.append(self.rackLetters[index])
        }
        for index in 0..<NUM_RACK_TILES {
            self.rackLetters[index] = copy[order[index]]
        }
    }
    
    func recallTiles() {
        var rackIndex = nextEmptyRackIndex(start: 0)
        if rackIndex == nil {
            self.rackTilesOnBoardCount = 0
            return
        }
        for row in 0..<NUM_BOARD_ROWS {
            for column in 0..<NUM_BOARD_COLUMNS {
                if !locked[row][column] && self.boardLetters[row][column] != INVISIBLE_LETTER {
                    var modifiedLetter = self.boardLetters[row][column]
                    if modifiedLetter.is_blank {
                        modifiedLetter = Letter(letter: BLANK, is_blank: true, value: modifiedLetter.value)
                    }
                    self.rackLetters[rackIndex!] = modifiedLetter
                    self.boardLetters[row][column] = INVISIBLE_LETTER
                    rackIndex = nextEmptyRackIndex(start: rackIndex!)
                    if rackIndex == nil {
                        self.rackTilesOnBoardCount = 0
                        return
                    }
                }
            }
        }
        self.rackTilesOnBoardCount = 0
    }
    private func nextEmptyRackIndex(start: Int) -> Int? {
        var rackIndex = start
        while rackIndex < NUM_RACK_TILES && self.rackLetters[rackIndex] != INVISIBLE_LETTER {
            rackIndex += 1
        }
        if rackIndex >= NUM_RACK_TILES {
            return nil
        }
        return rackIndex
    }
    
    
    func setBlank(choice: Character) {
        self.showBlankPicker = false
        let prevLetter = self.boardLetters[prevBlankRow!][prevBlankColumn!]
        assert(prevLetter.is_blank)
        assert(prevLetter.letter == BLANK)
        self.boardLetters[prevBlankRow!][prevBlankColumn!] = Letter(letter: choice, is_blank: true, value: prevLetter.value)
        self.prevBlankRow = nil
        self.prevBlankColumn = nil
    }
    
    func nearestRackEmpty(newIndex: Int, originalIndex: Int?) -> Int {
        for delta in 0..<NUM_RACK_TILES {
            if newIndex + delta < NUM_RACK_TILES {
                if newIndex + delta == originalIndex {
                    if self.rackShuffleState[newIndex + delta] == INVISIBLE_LETTER {
                        return newIndex + delta
                    }
                } else {
                    if self.rackLetters[newIndex + delta] == INVISIBLE_LETTER {
                        return newIndex + delta
                    }
                }
            }
            if newIndex - delta >= 0 {
                if newIndex - delta == originalIndex {
                    if self.rackShuffleState[newIndex - delta] == INVISIBLE_LETTER {
                        return newIndex - delta
                    }
                } else {
                    if self.rackLetters[newIndex - delta] == INVISIBLE_LETTER {
                        return newIndex - delta
                    }
                }
            }
        }
        return -1
    }
    
    func nearestBoardEmpty(targetRow: Int, targetColumn: Int) -> (Int, Int) {
        var vis = [[Bool]](repeating: [Bool](repeating: false, count: NUM_BOARD_COLUMNS), count: NUM_BOARD_ROWS)
        let rowQueue = IntQueue(maxSize: NUM_BOARD_ROWS * NUM_BOARD_COLUMNS)
        let columnQueue = IntQueue(maxSize: NUM_BOARD_ROWS * NUM_BOARD_COLUMNS)
        
        rowQueue.offer(targetRow)
        columnQueue.offer(targetColumn)
        let dr = [1, 0, -1, 0]
        let dc = [0, 1, 0, -1]
        
        vis[targetRow][targetColumn] = true
        while rowQueue.getSize() > 0 {
            let currRow = rowQueue.poll()!
            let currColumn = columnQueue.poll()!
            if self.boardLetters[currRow][currColumn] == INVISIBLE_LETTER {
                return (currRow, currColumn)
            }
            for index in 0..<4 {
                let nextRow = currRow + dr[index]
                let nextColumn = currColumn + dc[index]
                if nextRow < 0 || nextRow >= NUM_BOARD_ROWS || nextColumn < 0 || nextColumn >= NUM_BOARD_COLUMNS {
                    continue
                }
                if !vis[nextRow][nextColumn] {
                    vis[nextRow][nextColumn] = true
                    rowQueue.offer(nextRow)
                    columnQueue.offer(nextColumn)
                }
            }
        }
        return (-1, -1)
    }
    
    
    func readDragIndex(index: Int, originalIndex: Int?) -> Letter {
        if originalIndex != nil && index == originalIndex! {
            return self.rackShuffleState[index]
        }
        return self.rackLetters[index]
    }
    
    func setDragIndex(index: Int, originalIndex: Int?, letter: Letter) {
        if originalIndex != nil && index == originalIndex! {
            self.rackShuffleState[index] = letter
        } else {
            self.rackLetters[index] = letter
        }
    }
    
    func shiftRack(newIndex: Int, originalIndex: Int?) {
        let nearestEmptyIndex = nearestRackEmpty(newIndex: newIndex, originalIndex: originalIndex)
        
        var start = newIndex + 1
        let end = nearestEmptyIndex
        var step = 1
        if newIndex > nearestEmptyIndex {
            start = newIndex - 1
            step = -1
        }
        var prevLetter = readDragIndex(index: newIndex, originalIndex: originalIndex)
        setDragIndex(index: newIndex, originalIndex: originalIndex, letter: INVISIBLE_LETTER)
        for index in stride(from: start, through: end, by: step) {
            let tmpLetter = readDragIndex(index: index, originalIndex: originalIndex)
            setDragIndex(index: index, originalIndex: originalIndex, letter: prevLetter)
            prevLetter = tmpLetter
        }
    }
    
    func tileMoved(location: CGPoint, letter: Letter, position: Position) -> Position {
        // Make sure that the tile being dragged is always at the front.
        if position.rackIndex != nil {
            self.frontTaker = FrontTaker.rack
        } else if position.boardRow != nil {
            self.frontTaker = FrontTaker.board
        }
        for rackIndex in 0..<NUM_RACK_TILES {
            if self.rackSlots.slots[rackIndex].contains(location) {
                shiftRack(newIndex: rackIndex, originalIndex: position.rackIndex)
                return Position(boardRow: nil, boardColumn: nil, rackIndex: rackIndex)
            }
        }
        for row in 0..<NUM_BOARD_ROWS {
            for column in 0..<NUM_BOARD_COLUMNS {
                if boardSlots.grid[row][column].contains(location) {
                    return Position(boardRow: row, boardColumn: column, rackIndex: nil)
                }
            }
        }
        return Position(boardRow: nil, boardColumn: nil, rackIndex: nil)
    }
    
    func tileDropped(letter: Letter, startPosition: Position, endPosition: Position) {
        self.frontTaker = FrontTaker.unknown
        if endPosition.boardRow != nil && endPosition.boardColumn != nil {
            let endPair = nearestBoardEmpty(targetRow: endPosition.boardRow!, targetColumn: endPosition.boardColumn!)
            let endRow = endPair.0
            let endColumn = endPair.1
            if startPosition.rackIndex != nil {
                self.rackLetters[startPosition.rackIndex!] = INVISIBLE_LETTER
                if letter.is_blank {
                    self.showBlankPicker.toggle()
                    self.prevBlankRow = endRow
                    self.prevBlankColumn = endColumn
                }
                self.rackTilesOnBoardCount += 1
            } else {
                self.boardLetters[startPosition.boardRow!][startPosition.boardColumn!] = INVISIBLE_LETTER
            }
            self.boardLetters[endRow][endColumn] = letter
        } else if endPosition.rackIndex != nil {
            if startPosition.rackIndex != nil {
                self.rackLetters[startPosition.rackIndex!] = INVISIBLE_LETTER
                self.rackLetters[endPosition.rackIndex!] = letter
            }
            if startPosition.boardRow != nil && startPosition.boardColumn != nil {
                self.boardLetters[startPosition.boardRow!][startPosition.boardColumn!] = INVISIBLE_LETTER
                var modifiedLetter = letter
                if letter.is_blank {
                    modifiedLetter = Letter(letter: BLANK, is_blank: true, value: letter.value)
                }
                self.rackLetters[endPosition.rackIndex!] = modifiedLetter
                self.rackTilesOnBoardCount -= 1
            }
        } else {
            if startPosition.rackIndex != nil && self.rackShuffleState[startPosition.rackIndex!] != INVISIBLE_LETTER {
                // Make sure that we are not losing the dragged tile.
                for index in 0..<NUM_RACK_TILES {
                    if self.rackLetters[index] == INVISIBLE_LETTER {
                        self.rackLetters[index] = letter
                        break
                    }
                }
            }
        }
        for index in 0..<NUM_RACK_TILES {
            if self.rackShuffleState[index] != INVISIBLE_LETTER {
                self.rackLetters[index] = self.rackShuffleState[index]
            }
        }
        self.rackShuffleState = [Letter](repeating: INVISIBLE_LETTER, count: NUM_RACK_TILES)
    }
    
    private func setupBoardTiles() -> [[Tile]] {
        var boardTiles: [[Tile]] = []
        for row in 0..<NUM_BOARD_ROWS {
            var boardRow: [Tile] = []
            for column in 0..<NUM_BOARD_COLUMNS {
                boardRow.append(Tile(
                    size: self.width / NUM_BOARD_COLUMNS,
                    face: boardLetters[row][column],
                    position: Position(boardRow: row, boardColumn: column, rackIndex: nil),
                    allowDrag: true,
                    onChanged: self.tileMoved,
                    onEnded: self.tileDropped
                ))
            }
            boardTiles.append(boardRow)
        }
        return boardTiles
    }
    
    private func setupBoardSquares() -> [[BoardSquare]] {
        let colors = getBoardColors()
        var boardSquares: [[BoardSquare]] = []
        let size = self.width / NUM_BOARD_COLUMNS
        for row in 0..<NUM_BOARD_ROWS {
            var boardSquareRow: [BoardSquare] = []
            for column in 0..<NUM_BOARD_COLUMNS {
                boardSquareRow.append(BoardSquare(size: size, color: colors[row][column], row: row, column: column))
            }
            boardSquares.append(boardSquareRow)
        }
        return boardSquares
    }
    
    func getBoardColors() -> [[Color]] {
        var colors = Array(repeating: Array(repeating: Color.gray, count: 15), count: 15)
        colors[0][0] = Color.red
        colors[0][7] = Color.red
        colors[0][14] = Color.red
        colors[7][0] = Color.red
        colors[7][7] = Color.orange
        colors[7][14] = Color.red
        colors[14][0] = Color.red
        colors[14][7] = Color.red
        colors[14][14] = Color.red
        return colors
    }
    
    private func setupRackTiles() -> [Tile] {
        var rackTiles: [Tile] = []
        for index in 0..<NUM_RACK_TILES {
            rackTiles.append(Tile(
                    size: self.width / NUM_RACK_TILES,
                    face: self.rackLetters[index],
                    position: Position(boardRow: nil, boardColumn: nil, rackIndex: index),
                    allowDrag: true,
                    onChanged: self.tileMoved,
                    onEnded: self.tileDropped))
        }
        return rackTiles
    }
    
    private func setupShuffleState() -> [Tile] {
        var shuffleTiles: [Tile] = []
        for index in 0..<NUM_RACK_TILES {
            shuffleTiles.append(Tile(
                size: self.width / NUM_RACK_TILES,
                face: self.rackShuffleState[index],
                position: Position(boardRow: nil, boardColumn: nil, rackIndex: index),
                allowDrag: true,
                onChanged: self.tileMoved,
                onEnded: self.tileDropped))
        }
        return shuffleTiles
    }
    
    private func setupRackSquares() -> [RackSquare] {
        var rackSquares: [RackSquare] = []
        for index in 0..<NUM_RACK_TILES {
            rackSquares.append(RackSquare(size: self.width / NUM_RACK_TILES, color: Color.green, index: index))
        }
        return rackSquares
    }
}
