package com.michaelvandaniker.visualization
{
	import flash.display.BitmapData;
	import flash.events.Event;
	import flash.events.MouseEvent;
	
	import mx.core.UIComponent;
	import mx.events.CollectionEvent;
	
	/**
	 *  The color of the background of a renderer when the user rolls over it.
	 *
	 *  @default 0xB2E1E1
	 */
	[Style(name="rollOverColor", type="uint", format="Color", inherit="yes")]
	
	/**
	 *  The color of the background of a renderer when the user selects it.
	 *
	 *  @default 0x7FCEFF
	 */
	[Style(name="selectionColor", type="uint", format="Color", inherit="yes")]

	public class ComparisonMatrixPlotCell extends UIComponent implements IComparisonRenderer
	{
		public function ComparisonMatrixPlotCell()
		{
			super();
			addEventListener(MouseEvent.ROLL_OVER,handleRollOver);
			addEventListener(MouseEvent.ROLL_OUT,handleRollOut);
		}
		
		private var dataProviderDirty:Boolean;
		
		private var plotDirty:Boolean;
		
		private var oldWidth:Number;
		
		private var oldHeight:Number;
		
		private var xMin:Number;
		
		private var yMin:Number;
		
		private var xMax:Number;
		
		private var yMax:Number;
		
		private var xRange:Number;
		
		private var yRange:Number;
		
		private var plotBitmapData:BitmapData;
		
		/**
		 * Whether or not the user is currently rolled over this ComparisonMatrixCell
		 */
		private var isRolledOver:Boolean = false;
		
		[Bindable(event="labelFunctionChange")]
		/**
		 * The function used to determine what text should be shown in the cell.
		 * 
		 * The function should take a comparisonItem as an argument and return a String.
		 * If a function is not applied, no label is shown.
		 */
		public function set labelFunction(value:Function):void
		{
			if(value != _labelFunction)
			{
				_labelFunction = value;
				invalidateDisplayList();
				dispatchEvent(new Event("labelFunctionChange"));
			}
		}
		public function get labelFunction():Function
		{
			return _labelFunction;
		}
		private var _labelFunction:Function;
		
		[Bindable(event="alphaFunctionChange")]
		/**
		 * A function used to determine the alpha value of this interior of this ComparisonMatrixCell.
		 * 
		 * The function should take a comparisonItem as an argument and return a Number.
		 *  
		 * The default behavior is to use the absolute value of the comparisonItem's comparisonValue.
		 */
		public function set alphaFunction(value:Function):void
		{
			if(value != _alphaFunction)
			{
				_alphaFunction = value;
				invalidateDisplayList();
				dispatchEvent(new Event("alphaFunctionChange"));
			}
		}
		public function get alphaFunction():Function
		{
			return _alphaFunction;
		}
		private var _alphaFunction:Function;
		
		[Bindable(event="colorFunctionChange")]
		/**
		 * A function used to determine the color of this interior of this ComparisonMatrixCell.
		 * 
		 * The function should take a comparisonItem as an argument and return a uint.
		 *  
		 * The default behavior is to use red (0xff0000) for comparisonValues less than 0
		 * and blue (0xff) for all other values.
		 */
		public function set colorFunction(value:Function):void
		{
			if(value != _colorFunction)
			{
				_colorFunction = value;
				invalidateDisplayList();
				dispatchEvent(new Event("colorFunctionChange"));
			}
		}
		public function get colorFunction():Function
		{
			return _colorFunction;
		}
		private var _colorFunction:Function;
		
		[Bindable(event="selectedChange")]
		/**
		 * Whether or not this ComparisonMatrixCell should appear selected.
		 */
		public function set selected(value:Boolean):void
		{
			if(value != _selected)
			{
				_selected = value;
				invalidateDisplayList();
				dispatchEvent(new Event("selectedChange"));
			}
		}
		public function get selected():Boolean
		{
			return _selected;
		}
		private var _selected:Boolean = false;
		
		[Bindable(event="comparisonMatrixItemChange")]
		/**
		 * The comparisonItem this ComparisonMatrixItem should render.
		 */
		public function set comparisonItem(value:ComparisonItem):void
		{
			if(value != _comparisonMatrixItem)
			{
				if(_comparisonMatrixItem && _comparisonMatrixItem.dataProvider)
					_comparisonMatrixItem.dataProvider.removeEventListener(CollectionEvent.COLLECTION_CHANGE,handleCollectionChange);
				_comparisonMatrixItem = value;
				if(_comparisonMatrixItem && _comparisonMatrixItem.dataProvider)
					_comparisonMatrixItem.dataProvider.addEventListener(CollectionEvent.COLLECTION_CHANGE,handleCollectionChange);
				
				dataProviderDirty = true;
				invalidateProperties();
				dispatchEvent(new Event("comparisonMatrixItemChange"));
			}
		}
		public function get comparisonItem():ComparisonItem
		{
			return _comparisonMatrixItem;
		}
		private var _comparisonMatrixItem:ComparisonItem;
		
		protected function handleCollectionChange(event:CollectionEvent):void
		{
			dataProviderDirty = true;
			invalidateProperties();
		}
		
		override protected function commitProperties():void
		{
			super.commitProperties();
			if(dataProviderDirty)
			{
				updateExtremes();
				
				plotDirty = true;
				invalidateDisplayList();
				dataProviderDirty = false;
			}
		}
		
		private function updateExtremes():void
		{
			if(comparisonItem && comparisonItem.dataProvider)
			{
				xMin = Number.MAX_VALUE;
				yMin = Number.MAX_VALUE;
				xMax = Number.MIN_VALUE;
				yMax = Number.MIN_VALUE;
				for each(var o:Object in comparisonItem.dataProvider)
				{
					xMin = Math.min(xMin,o[comparisonItem.xField]);
					yMin = Math.min(yMin,o[comparisonItem.yField]);
					xMax = Math.max(xMax,o[comparisonItem.xField]);
					yMax = Math.max(yMax,o[comparisonItem.yField]);
				}
				xRange = xMax - xMin;
				yRange = yMax - yMin;
			}
		}
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth,unscaledHeight);
			this.graphics.clear();
			if(comparisonItem)
			{
				drawBackground();
				if(plotDirty || oldWidth != width || oldHeight != height)
				{
					updatePlot();
					plotDirty = false;
					oldWidth = width;
					oldHeight = height;
				}
				drawPlot();
			}
		}
		
		private function drawBackground():void
		{
			// Determine the color and alpha value of the interior of the ComparisonMatrixCell
			// based on the selected or isRolledOver properties or the comparisonValues itself. 
			var color:Number;
			var alpha:Number = 1;
			if(selected)
			{
				color = getStyle("selectionColor");
			}
			else if(isRolledOver)
			{
				color = getStyle("rollOverColor");
			}
			else
			{
				if(colorFunction != null)
					color = colorFunction.apply(this,[comparisonItem]);
				else
					color = comparisonItem.comparisonValue > 0 ? 0xff0000 : 0xff;
				
				if(alphaFunction != null)
					alpha = alphaFunction.apply(this,[comparisonItem]);
				else
					alpha = Math.abs(comparisonItem.comparisonValue);
			}
			
			// Draw the box
			this.graphics.lineStyle(1,0);
			this.graphics.beginFill(color,alpha);
			this.graphics.drawRect(0,0,width,height);
			this.graphics.endFill();
		}
		
		private function updatePlot():void
		{
			if(plotBitmapData)
				plotBitmapData.dispose();
			plotBitmapData = new BitmapData(width,height,true,0xffffff);
			
			for each(var o:Object in comparisonItem.dataProvider)
			{
				var plotPointX:int = computeX(o);
				var plotPointY:int = computeY(o);
				plotBitmapData.setPixel32(plotPointX,plotPointY,0xff000000);
			}	
		}
		
		private function drawPlot():void
		{
			this.graphics.beginBitmapFill(plotBitmapData);
			this.graphics.drawRect(0,0,width,height);
			this.graphics.endFill();
		}
		
		private function computeX(o:Object):int
		{
			var xFieldValue:Number = o[comparisonItem.xField];
			var xPercent:Number = 1 - (xMax - xFieldValue) / xRange;
			return width * xPercent;
		}
		
		private function computeY(o:Object):int
		{
			var yFieldValue:Number = o[comparisonItem.yField];
			var yPercent:Number = (yMax - yFieldValue) / yRange;
			return height * yPercent;
		}
		
		// Handler for rolling the mouse over the ComparisonMatrixCell.
		// Set the isRolledOver property and invalidate.
		private function handleRollOver(event:MouseEvent):void
		{
			isRolledOver = true;
			invalidateDisplayList();
		}
		
		// Handler for rolling the mouse out of the ComparisonMatrixCell.
		// Set the isRolledOver property and invalidate.
		private function handleRollOut(event:MouseEvent):void
		{
			isRolledOver = false;
			invalidateDisplayList();
		}
	}
}